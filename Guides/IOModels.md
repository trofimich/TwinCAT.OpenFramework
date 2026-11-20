# IO models: mapping and supported process images

The library provides passive PLC endpoints. It does not configure EtherCAT devices, discover links, validate
measurements or advance serial handshakes. Select the documented process image in XAE before linking fields.
Zero-valued, unlinked inputs can look plausible; commissioning must confirm the links independently.

Use one owner task per model instance. Synchronize other tasks and ADS writes externally. A record copy stores
data; it creates no new I/O links and provides no atomic multi-field snapshot guarantee. Keep borrowed field
references valid while consumers are bound. Compiler padding and `SIZEOF(record)` do not define an EtherCAT packet.

## Supported representations

| Model | Represented process image | Configuration boundary |
|---|---|---|
| Standard analog inputs | Status WORD plus the declared INT/DINT/REAL Value | Select that standard PDO; compact value-only layouts are outside the model. |
| EL3078 | Eight status-plus-REAL32 channels | Select AI Standard (Real32), Tx 0x1A10/12/14/16/18/1A/1C/1E; Value is 0x60n0:13. ADC resolution does not determine PDO width. |
| RTD and thermocouple inputs | Status WORD plus raw INT16 | Configure presentation; 0.1 and 0.01 degrees C per digit are different settings. |
| Analog outputs | Raw INT16 command per channel | Configure electrical range, representation and user scaling before operation. |
| EL1502 | Two 32-bit counters; Tx 0x1A00/0x1A01, Rx 0x1600/0x1601 | Select 2Ch. Counter; the factory single up/down counter is a different image. |
| EL1512 | Default two-counter image | Single-channel up/down/gated modes are outside the model. |
| EL5101 | Enhanced Standard 32-bit; Tx 0x1A04, Rx 0x1603 | Requires firmware 14 / hardware 09 or later supporting enhanced mode. |
| EL5151 | 32-bit main counter/latch PDOs | Optional period/frequency/timestamp PDOs must be linked separately if enabled. |
| EL5152 | 32-bit main counter PDOs, without latch | Ch1: Tx 0x1A00/Rx 0x1600; Ch2: Tx 0x1A04/Rx 0x1602. Optional PDOs are separate. |
| EL5001/EL5002 | Position UDINT plus two-byte status | EL5001 requires firmware 11+ and the two-byte status variant; one-byte status is unsupported. |
| EL2502 | Duty-only standard PWM, signed presentation | Configure period acyclically; cyclic-period and unsigned variants are separate images. |
| EL2521 | Enhanced Standard 32-bit with target and counter feedback/control | Tx 0x1A01/0x1A05; Rx 0x1601/0x1607/0x1605. Frequency is still UINT16 raw data. |
| EL3356/EL3356-0010 | One-channel INT32 load: Status Tx 0x1A00, Value Tx 0x1A01, Control Rx 0x1600 | Keep both input PDOs enabled and link Status and Value separately. REAL load, voltage mode and optional filter/timestamp PDOs are separate images. |
| EL3403 | Three specialized phase channels plus terminal Status | Map phase status and the separate terminal Status PDO 0x1A03. |
| EL3413/EL3433 | Three phase channels plus Auxiliary | Map phase status, auxiliary Tx 0x1A03 and selectors Rx 0x1603. |
| Serial EL/EP models | 16-bit status/control plus 22-byte payload in each direction | Larger buffers and 9-bit modes are outside the model. Configure the electrical interface separately. |

The declarations describe represented fields, not every optional PDO supplied by the ESI. Check the actual
device revision, firmware and ESI. Disable unneeded optional PDOs or link their data separately.

## Validity and selectors

`WcState=TRUE` means invalid process-data exchange. `InputToggle` is an update transition, not a ready level.
`State` and `AdsAddr` are acyclic information; they do not validate a current measurement. Evaluate the channel's
own status as well. EL3403 phase synchronization status differs from EL3413/EL3433 measurement status.

Power measurement `Current` and `Voltage` are signed raw values. Their default units are 0.000001 A and 0.0001 V;
apply the configured transformer ratios and device-variant scaling. Interpret `VariantValue` only after the
input `Index` acknowledges the requested output selector and the relevant status is valid. For Auxiliary,
both `Index` and `Channel` must acknowledge the request; units depend on the selected quantity and firmware.

EL2521 `Frequency` preserves a 16-bit raw command, including the selected sign representation. Relative mode
scales the base frequency by the interpreted command divided by 32767; direct mode uses the configured factor
in 0.01 Hz units. The 32-bit target and counter preset are separate fields.

Relay specifications are device-specific:

- EL2622: two normally open make contacts, 230 V AC / 30 V DC; 5 A resistive or 2 A inductive per channel.
- EL2624: four normally open make contacts, 125 V AC / 30 V DC; 0.5 A AC / 2 A DC resistive per channel.
- EP2624-0002: four normally open make contacts, 25 V AC / 30 V DC; 0.5 A AC / 2 A DC per channel.

## Simple EP models and mailbox support

The following models expose discrete endpoints and bus diagnostics; their slaves have no CoE mailbox.
Their `_EX` types provide WcState and State, plus InputToggle for inputs. They have no AdsAddr endpoint.

| Model | Discrete endpoints |
|---|---|
| EP1008_0001 / EP1008_0002 | Eight BOOL inputs |
| EP1018_0001 | Eight BOOL inputs |
| EP1809_0021 | Sixteen BOOL inputs |
| EP2008_0001 / EP2008_0002 | Eight BOOL outputs |
| EP2809_0021 | Sixteen BOOL outputs |
| EP2624_0002 | Four BOOL relay commands |

EP1809_0021 and EP2809_0021 use the documented 16-channel M8 product identifiers (replacing the old `_0001` names; update declarations and XAE links accordingly). Because unsupported `AdsAddr` fields were removed from simple EP models, rebuild dependent projects and review your mappings. EP3174_0002_EX, EP4174_0002_EX, and the serial EP6001/EP6002 extensions retain their CoE `AdsAddr` endpoints — do not assume mailbox support from the `EP` prefix alone.

Thermocouple models represent input PDOs. External cold-junction compensation requires additional output
PDOs linked separately; input-only records do not supply the compensation temperature.

## Example and verification

`Sources/TwinCAT.OpenFramework.HowTo/IO/IOModelsExample.TcPOU` demonstrates an EL3001_EX input. Link all declared
endpoints, confirm the selected PDO, then set `BindingsConfigured=TRUE`. Invoke `Execute` once per task cycle
or map the program itself to that task. Inspect `InputValid`, `InputUpdated` and `Voltage`. The existing HowTo
MAIN continues to run its testing example; the IO example is selected explicitly during commissioning.

`IOModelsTest` runs automatically via `TcUnit` and checks PLC field types and byte widths (including the 16-channel EP models, `EL3078` `Real32`, and compound `DINT`/`REAL` inputs). Unit tests do not verify physical EtherCAT wiring or TwinCAT XAE links, so check those during commissioning:

* Confirm that the eight simple EP `_EX` models have no `AdsAddr`, while analog and serial EP `_EX` models keep theirs.
* For `EL3356`, link Status PDO `0x1A00` and integer Value PDO `0x1A01` separately.
* For `EL3078`, select `AI Standard (Real32)` and link the `REAL32` Value at `0x60n0:13`.
* In XAE, verify every linked field's direction and bit width before starting operation — never hide a width mismatch by truncating values, and test bus loss, channel faults, selector switching, scaling, and recovery on real hardware.
* Because outdated duplicates were removed and public layouts updated, rebuild dependent projects and review existing I/O mappings after upgrading.

## Beckhoff references

- [EL2521 PDOs](https://infosys.beckhoff.com/content/1033/el252x/1702203147.html)
- [EL2521 command interpretation](https://infosys.beckhoff.com/content/1033/el252x/11019769227.html)
- [EL515x main and optional PDOs](https://infosys.beckhoff.com/content/1033/el515x/1525535883.html)
- [EL3403 PDO assignment](https://infosys.beckhoff.com/content/1033/el3403/2030692875.html)
- [EL3413/EL3433 PDO assignment](https://infosys.beckhoff.com/content/1033/el34x3/2345766795.html)
- [EL3413/EL3433 input quantities](https://infosys.beckhoff.com/content/1033/el34x3/2346734091.html)
- [EL500x status variants](https://infosys.beckhoff.com/content/1033/el500x/2247264523.html)

- [EL2622 relay specifications](https://www.beckhoff.com/en-en/products/i-o/ethercat-terminals/el-ed2xxx-digital-output/el2622.html)
- [EL2624 relay specifications](https://www.beckhoff.com/en-en/products/i-o/ethercat-terminals/el-ed2xxx-digital-output/el2624.html)
- [EL3356 status and load PDOs](https://infosys.beckhoff.com/content/1033/el3356/1981070347.html)
- [Official Beckhoff ESI archive](https://download.beckhoff.com/download/configuration-files/io/ethercat/xml-device-description/Beckhoff_EtherCAT_XML.zip)
