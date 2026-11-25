using System.Text;
using System.Xml;
using System.Xml.Linq;
using TwinCAT;
using TwinCAT.Ads;
using TwinCAT.Ads.TypeSystem;
using TwinCAT.TypeSystem;

const string controllerPath = "MAIN.TestAutomationUnit";
const int port = 864;
const int junitChunkSize = 1023;

if (!TryParseArguments(args, out int timeoutSeconds, out string? junitPath))
{
    Console.Error.WriteLine("Usage: OpenFramework.TestCli [timeout-seconds: 1..86400] [--junit <path>]");
    return 2;
}

using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSeconds));
using var client = new AdsClient();
string operation = $"read the test results on local ADS port {port}";
try
{
    if (junitPath is not null)
    {
        operation = $"prepare the JUnit output at '{junitPath}'";
        junitPath = Path.GetFullPath(junitPath);
        Directory.CreateDirectory(Path.GetDirectoryName(junitPath)!);
        File.Delete(junitPath);
    }

    operation = $"read the test results on local ADS port {port}";
    client.Connect(port);
    var loader = SymbolLoaderFactory.Create(client, SymbolLoaderSettings.DefaultDynamic);
    var symbols = await loader.GetSymbolsAsync(deadline.Token);
    if (!symbols.Succeeded)
        throw new InvalidOperationException($"Could not load PLC symbols (ADS: {symbols.ErrorCode}).");

    if (symbols.Symbols is not { } symbolCollection ||
        !symbolCollection.TryGetInstance(controllerPath, out var controller) ||
        controller is null)
    {
        throw new InvalidOperationException($"Could not resolve {controllerPath}.");
    }

    var testsFinished = GetProperty(controller, "TestsFinished");
    while (!await Read<bool>(testsFinished))
        await Task.Delay(250, deadline.Token);

    int mainExit = await Read<int>(GetProperty(controller, "MainTestExitCode"));
    int contractFailures = await Read<int>(GetProperty(controller, "ContractTestFailures"));
    Console.WriteLine($"Main tree exit code: {mainExit}. Failed runner contract scenarios: {contractFailures}.");

    if (mainExit != 0)
        await PrintDiagnostic(controller, "MainTestDiagnostic");
    string? contractDiagnostic = contractFailures > 0
        ? await PrintDiagnostic(controller, "ContractTestDiagnostic")
        : null;

    if (mainExit < 0)
    {
        Console.Error.WriteLine("Main test run aborted.");
        return 2;
    }

    if (junitPath is not null)
    {
        operation = $"export the JUnit report to '{junitPath}'";
        if (contractFailures > 0 && contractDiagnostic is null)
            throw new InvalidOperationException("The runner contract failure diagnostic could not be read.");

        XDocument report = await ReadJUnitReport(controller, mainExit, contractFailures, contractDiagnostic);
        await PublishJUnitReport(report, junitPath, deadline.Token);
        Console.WriteLine($"JUnit report written to '{junitPath}'.");
    }

    if (mainExit > 0 || contractFailures > 0)
        return 1;

    Console.WriteLine("Both suites passed.");
    return 0;
}
catch (Exception) when (deadline.IsCancellationRequested)
{
    Console.Error.WriteLine($"Timed out after {timeoutSeconds} seconds while trying to {operation}.");
    return 2;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Could not {operation}: {ex.Message}");
    return 2;
}

static bool TryParseArguments(string[] arguments, out int timeout, out string? outputPath)
{
    timeout = 180;
    outputPath = null;
    bool timeoutSpecified = false;

    for (int index = 0; index < arguments.Length; index++)
    {
        string argument = arguments[index];
        if (argument == "--junit")
        {
            if (outputPath is not null || ++index == arguments.Length ||
                string.IsNullOrWhiteSpace(arguments[index]) || arguments[index].StartsWith("--", StringComparison.Ordinal))
                return false;

            outputPath = arguments[index];
        }
        else
        {
            if (timeoutSpecified || !int.TryParse(argument, out timeout) || timeout is < 1 or > 86400)
                return false;

            timeoutSpecified = true;
        }
    }

    return true;
}

static IValueSymbol GetProperty(ISymbol controller, string propertyName)
{
    if (controller.SubSymbols.TryGetInstance(propertyName, out var symbol)
        && symbol is IValueSymbol property)
        return property;

    throw new InvalidOperationException($"Could not resolve {controller.InstancePath}.{propertyName}.");
}

async Task<T> Read<T>(IValueSymbol property)
{
    var result = await property.ReadValueAsync(deadline.Token);
    if (!result.Succeeded || result.Value is not T value)
        throw new InvalidOperationException(
            $"Could not read {property.InstancePath} as {typeof(T).Name} (ADS: {result.ErrorCode}).");

    return value;
}

async Task<string?> PrintDiagnostic(ISymbol controller, string propertyName)
{
    try
    {
        string diagnostic = await Read<string>(GetProperty(controller, propertyName));
        if (!string.IsNullOrWhiteSpace(diagnostic))
            Console.Error.WriteLine(diagnostic);
        return diagnostic;
    }
    catch (Exception ex) when (!deadline.IsCancellationRequested)
    {
        Console.Error.WriteLine($"Could not read {propertyName}: {ex.Message}");
        return null;
    }
}

async Task<XDocument> ReadJUnitReport(ISymbol controller, int mainExit, int contractFailures, string? contractDiagnostic)
{
    uint contentLength = await Read<uint>(GetProperty(controller, "MainJUnitContentLength"));
    if (contentLength == 0)
        throw new InvalidOperationException("The PLC JUnit report is unavailable.");

    var content = new StringBuilder();
    var chunkType = new AnyTypeSpecifier(typeof(string), junitChunkSize, Encoding.ASCII);
    for (uint offset = 0; offset < contentLength;)
    {
        uint expectedLength = Math.Min((uint)junitChunkSize, contentLength - offset);
        var result = await client.InvokeRpcMethodAsync(
            controller.InstancePath, "ReadMainJUnitChunk", [offset], null, chunkType, deadline.Token);
        var chunk = result.ReturnValue as string;
        if (!result.Succeeded || chunk is null || chunk.Length != expectedLength)
            throw new InvalidOperationException($"Could not read JUnit XML at byte {offset} (ADS: {result.ErrorCode}).");

        content.Append(chunk);
        offset += expectedLength;
    }

    using var reader = XmlReader.Create(new StringReader(content.ToString()));
    XDocument document = XDocument.Load(reader);
    if (document.Root is not { } root || root.Name != "testsuites")
        throw new InvalidDataException("Expected a JUnit testsuites root.");

    XElement[] suites = root.Elements().ToArray();
    if (suites.Length != 1 || suites[0].Name != "testsuite")
        throw new InvalidDataException("Expected one main JUnit testsuite from the PLC.");

    XElement mainSuite = suites[0];
    XElement[] mainCases = mainSuite.Elements("testcase").ToArray();
    int mainFailures = mainCases.Count(testCase => testCase.Element("failure") is not null);
    int mainSkipped = mainCases.Count(testCase => testCase.Element("skipped") is not null);
    if (mainFailures != mainExit)
        throw new InvalidDataException("The JUnit failure count differs from the main test result.");

    mainSuite.SetAttributeValue("tests", mainCases.Length);
    mainSuite.SetAttributeValue("failures", mainFailures);
    mainSuite.SetAttributeValue("skipped", mainSkipped);

    var contractCase = new XElement("testcase",
        new XAttribute("name", "TestRunnerContractTest"),
        new XAttribute("classname", "OpenFramework.RunnerContracts"));
    int failedContractCases = contractFailures > 0 ? 1 : 0;
    if (failedContractCases > 0)
    {
        contractCase.Add(new XElement("failure",
            new XAttribute("type", "RunnerContractFailure"),
            new XAttribute("message", $"Failed runner contract scenarios: {contractFailures}."),
            contractDiagnostic));
    }

    root.Add(new XElement("testsuite",
        new XAttribute("name", "OpenFramework.RunnerContracts"),
        new XAttribute("tests", 1),
        new XAttribute("failures", failedContractCases),
        contractCase));
    root.SetAttributeValue("tests", mainCases.Length + 1);
    root.SetAttributeValue("failures", mainFailures + failedContractCases);
    root.SetAttributeValue("skipped", mainSkipped);
    return document;
}

static async Task PublishJUnitReport(XDocument report, string outputPath, CancellationToken cancellationToken)
{
    // Keep the staging file on the same filesystem so the final rename publishes a complete file.
    string temporaryPath = Path.Combine(Path.GetDirectoryName(outputPath)!, $".{Guid.NewGuid():N}.tmp");
    var stream = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None);
    try
    {
        await using (stream)
            await report.SaveAsync(stream, SaveOptions.DisableFormatting, cancellationToken);

        cancellationToken.ThrowIfCancellationRequested();
        File.Move(temporaryPath, outputPath);
    }
    catch
    {
        File.Delete(temporaryPath);
        throw;
    }
}
