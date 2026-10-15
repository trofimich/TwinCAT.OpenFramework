# Коментарі DocGen — 2026-10-06

## Рішення та межі

За дорученням власника старі та додані під час аудиту документаційні коментарі
в деклараціях Sources переведено на XML-формат TwinCAT Documentation Generation
(TcDocGen, TE1030). Це зміна документації, а не нове погодження контрактів.
Зміст пояснень і передумов збережено; відсутні описи не дописувалися автоматично.

Охоплено `.TcPOU`, `.TcIO`, `.TcDUT`, `.TcGVL`, включно з вкладеними деклараціями
методів і властивостей. Коментарі алгоритмів усередині реалізацій та закоментований
код залишаються звичайними ST-коментарями: вони не є API-документацією.
Історичні матеріали аудиту не переписувалися під нову ліцензію.

Джерело актуальної ліцензії — кореневий `LICENSE.txt`: MIT.
Наявні SPDX notices з LGPL-3.0-only замінено на MIT; авторство й роки збережено.
Файлам без наявного notice автоматично не приписувалося авторство.

## Формат для наступних змін

Документацію розташовуємо в Declaration перед декларацією об'єкта й attributes.
Для одного об'єкта використовуємо один summary; деталізацію контракту пишемо
в description. Для методу чи властивості опис розміщуємо біля їхньої декларації,
а не в загальному заголовку FB.

```structuredtext
(*
SPDX-FileCopyrightText: © 2026 Oleksandr Tiutyk <trofimich@gmail.com>
SPDX-License-Identifier: MIT
License: https://opensource.org/license/mit
*)

(*!
<summary>Short statement of purpose.</summary>
<description>
Explain the contract, ownership, lifetime and relevant restrictions here.
</description>
*)
//!<param name="object">A borrowed reference that must remain alive during the call.</param>
METHOD Example
VAR_INPUT
    object : IObject;
END_VAR
```

Ліцензійний блок — звичайний коментар; не додаємо його до summary API.
DocGen-коментарі починаються з `(*!` або `//!`. Не змішуємо Markdown/rST
з XML-розміткою DocGen. У тексті XML екрануємо `&`, `<`, `>`.
За потреби розділів використовуємо підтримувану DocGen розмітку,
наприклад `<h2>`, а не Markdown-заголовки.
Мову наявних описів під час цієї міграції не змінювали.

Підстава формату — документація Beckhoff:
[правила коментарів](https://infosys.beckhoff.com/content/1033/te1030_tc3_documentation_generation/10365497611.html),
[опис параметрів](https://infosys.beckhoff.com/content/1033/te1030_tc3_documentation_generation/10806225291.html).

## Статус

Формат і MIT погоджені власником. Генерацію документації та вигляд результату
в його конфігурації ще перевіряє власник. Кількісний migration report і резервні
копії docgen-before видалені під час погодженого прибирання 2026-10-16.
