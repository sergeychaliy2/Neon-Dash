# Анализ рынка playable-рекламы

Дата: 2026-10-15. Источники перечислены в конце.

> **Достоверность.** Почти вся статистика по конверсии исходит от вендоров,
> которые продают инструменты для UA (Segwise, SocialPeta, ironSource, Appodeal).
> Такие числа направленные, а не точные: считать их завышенными — безопаснее.
> Спеки сетей в открытых гайдах **противоречат друг другу**, официальной
> документации в выдаче не было. Перед реальной отправкой креатива спеку надо
> подтверждать в текущем документе самой сети. Раздел «Замеры» — наоборот,
> проверено локально и воспроизводимо.

## 1. Формат: чем playable является технически

Playable — это **один самодостаточный `index.html`**: разметка, CSS, скрипты,
спрайты, звуки — всё инлайном (как правило base64 data URI). Внешних запросов нет,
потому что креатив проигрывается внутри webview без гарантии сети.

Выход в стор делается не ссылкой, а вызовом API сети: `mraid.open()` у MRAID-сетей,
`window.install()` у Mintegral, собственный хук у Meta (которая прямо запрещает
подключать `mraid.js`).

### Лимиты по сетям

| Сеть | Лимит | Упаковка | Протокол |
|---|---|---|---|
| Unity Ads / LevelPlay | ~5 МБ | один инлайненый HTML | MRAID 3.0 (fallback 2.0) |
| ironSource (в составе LevelPlay) | 4–5 МБ (гайды расходятся) | один HTML | MRAID 3.0 / 2.0 |
| AppLovin MAX | ~5 МБ | один HTML, всё встроено | MRAID 2.0/3.0 (данные расходятся) |
| Mintegral | ~5 МБ | HTML **или** ZIP | свой API, `window.install()` |
| Google App campaigns | 5 МБ | ZIP, ≤512 файлов | HTML5-ассет |
| **Meta** | **2 МБ** | HTML (ZIP до 5 МБ где поддержан) | **без `mraid.js`** |

Практический вывод: **целиться в ≤2 МБ**. Это проходит везде, включая Meta,
и снимает необходимость держать разные билды под разные сети. Отдельно стоит
помнить, что 500 КБ грузятся на 4G примерно в 4 раза быстрее 2 МБ, а скорость
первого кадра напрямую влияет на то, доживёт ли пользователь до геймплея.

## 2. Что работает в креативе

**Хук.** Ясность геймплея по-прежнему решает, но внимание надо забрать за первые
**3 секунды**. Сильные креативы сначала показывают проблему, шок или награду, и уже
потом механику — это поднимает view-through на 30–50% (вендорская оценка).

**Одна механика, один глагол.** Рекомендация повторяется во всех гайдах: вытащить
из игры ровно один глагол — merge, match, pull the pin, build, shoot — и показать
только его. Туториал — одно направленное действие, стартовый экран — два-три
смысловых центра, не больше.

**Жанры по объёму креативов** (SocialPeta, 2024): casual — 1.5 млн, action — свыше
1 млн. Puzzle-механики составляют около 18% игровых объектов в топовых плейблах.

**Честность механики.** Расхождение рекламы с игрой надувает установки и убивает
retention; сети со временем наказывают это худшей доставкой.

**Связка video→playable.** У топовых кампаний playable идёт сразу за видео: по одному
разбору, 80% лучших видеокреативов Screwdom переходили в playable. Схема — зацикленное
видео-вступление, одно внятное взаимодействие, затем стор.

**Выгорание.** Срок жизни креатива в зрелых гео — менее 5 дней; меньше 4–6 новых
креативов в месяц означает структурное отставание по экономике UA. В среднем 64.8%
плейблов за месяц — новые.

## 3. Замеры: пригодность Flutter (локально, воспроизводимо)

Flutter 3.47.7 stable, Dart 3.13.5, Windows 11.

| Сборка | Размер |
|---|---|
| Flutter Web, пустой counter-app: `main.dart.js` (1851 КБ) + `canvaskit/chromium/canvaskit.wasm` (5302 КБ) | **7.0 МБ** |
| то же, инлайн в один HTML (base64, +33%) | **~9.4 МБ** |
| Весь каталог `build/web` | 39.2 МБ |
| **Dart→JS** (`dart compile js -O4`), сцена: 400 частиц, физика, Canvas2D | **46.4 КБ** (gzip 14.6 КБ) |

**Вывод по Flutter Web: не пригоден для playable-рекламы.** Пустое приложение
превышает лимит любой сети примерно вдвое — ещё до первой строки игрового кода.
HTML-рендерер удалён в Flutter 3.29, поэтому выбора движка больше нет: dart2js
тянет CanvasKit, dart2wasm тянет skwasm, и оба весят мегабайты. Оптимизацией это
не решается. Дополнительно против: старт движка 1–2 с против требуемого
мгновенного первого кадра, и зависимость от WebGL в ограниченных webview.

**Вывод по Dart без Flutter: пригоден с большим запасом.** 46 КБ на реальную
игровую сцену — это 2.3% от целевого бюджета 2 МБ. Остаток уходит на контент,
а не на рантайм.

**Вывод по Flutter для ПК и Android: пригоден и предпочтителен.** Ограничение
веса касалось только web-доставки; в нативных сборках CanvasKit не участвует,
а `CustomPainter` даёт прямой доступ к Skia без дерева виджетов в кадре.

## 4. Что из этого взято в проект

| Наблюдение рынка | Решение в коде |
|---|---|
| Хук за 3 секунды | Игра стартует сразу в движении, без меню и прелоадера |
| Один глагол | Единственный ввод — горизонтальный свайп/перетаскивание |
| Ясность на малом экране | Процедурный неон: высокий контраст фигуры к фону, глоу только на значимых объектах |
| Вес рантайма | Ядро без `dart:ui`; графика процедурная, спрайт-атласов нет вовсе |
| Мгновенный первый кадр | Нет загрузки ассетов: всё рисуется кодом |
| Повторная попытка после провала | Рестарт одним тапом, сразу в движении, без экрана-прослойки. Раскладка при рестарте **новая**: поток случайных чисел продолжается, а не сбрасывается, иначе повтор награждал бы запоминание вместо реакции. Воспроизводимый прогон по сиду оставлен отдельным методом — для тестов и реплеев |

## Источники

- [Playable Ad Size Limits by Network (Google, Meta, Unity, TikTok)](https://www.playableendcards.com/blog/playable-ad-size-limits-by-network)
- [Playable Ad File Size Limits — Network Table & Optimization](https://playableadsmaker.com/blog/playable-ad-size-limits-by-network)
- [Playable Ad Networks: Specs by Network (2026)](https://www.sett.ai/content/playable-ad-networks/)
- [Playable Ad File Size Limits by Network (2026 Guide)](https://alconost.video/en/blog/playable-ad-file-size-limits)
- [HTML5 Playable Ads: A Practical Guide](https://segwise.ai/blog/html5-playable-ads-guide)
- [playable-sdk — унифицированный MRAID/Google/Facebook/Vungle SDK](https://github.com/smoudjs/playable-sdk)
- [Ad Networks Overview — Luna Labs docs](https://docs.lunalabs.io/docs/playable/ad-networks/overview/)
- [Playable Ads Guide 2026: Why They Dominate Mobile UA](https://segwise.ai/blog/understanding-playable-ads-guide.md)
- [How Screwdom 3D Cracked the Creative Code: 4 Ad Patterns for 2026](https://segwise.ai/blog/screwdom-ad-strategy-creative-patterns.md)
- [How to Produce Playable Ads at Scale for Mobile Games (2026)](https://segwise.ai/blog/produce-playable-ads-at-scale.md)
- [Best Practices for Creating and Implementing Effective Playable Ads](https://craftsmanplus.com/resources/best-practices-for-creating-and-implementing-effective-playable-ads)
- [Playable ads trends in mobile games — Matej Lancaric](https://lancaric.substack.com/p/playable-ads-trends-in-mobile-games-f7b)
- [CanvasKit vs skwasm for Flutter web in 2026](https://startdebugging.net/2026/09/canvaskit-vs-skwasm-for-flutter-web-in-2026/)
- [Flutter Web: Areas Where It Can Improve](https://www.walturn.com/insights/flutter-web-areas-where-it-can-improve)
