# Post Explorer (SRS 8)

Flutter-приложение для просмотра, поиска и создания постов на базе
[JSONPlaceholder](https://jsonplaceholder.typicode.com/).
Стек: **Dio + Retrofit + json_serializable + Provider + SharedPreferences**.

## Запуск

```bash
# в корне репозитория (один раз — создаст android/ios и т.п.)
flutter create . --platforms=android,ios --project-name post_explorer

flutter pub get
dart run build_runner build --delete-conflicting-outputs   # генерация *.g.dart
flutter run
flutter test
```

> Файлы `*.g.dart` не хранятся в git — их создаёт `build_runner`.

## Архитектура

```
Presentation  (screens · widgets · state)   <- знает только про Repository
     │
Repository    (PostRepository, PostFilter)   <- сеть + кэш + ошибки
     │
Data sources  remote: PostApi (Retrofit) + DioClient/Interceptors
              local:  PostCache (SharedPreferences)
     │
JSONPlaceholder REST API
```

```
lib/
├── core/
│   ├── network/  dio_client.dart, api_interceptor.dart
│   └── error/    app_exception.dart
├── data/
│   ├── models/   post, comment, user (+ Company, Address), create_post_request
│   ├── remote/   post_api.dart            (Retrofit, 7 запросов)
│   ├── local/    post_cache.dart
│   └── repositories/ post_repository.dart, post_filter.dart
├── presentation/
│   ├── screens/  список, детали, создание
│   ├── widgets/  post_tile, error_view
│   └── state/    контроллеры (ChangeNotifier + Provider)
└── main.dart
```

### Зачем нужны компоненты

| Компонент | Задача |
|---|---|
| **Dio** | HTTP-клиент: таймауты, interceptors, логирование. Один экземпляр на приложение (`DioClient`). |
| **Retrofit** | Декларативное описание эндпоинтов (`PostApi`): вместо ручной сборки URL и запросов — типизированные методы. |
| **json_serializable** | Генерация `fromJson/toJson`: нет ручного парсера, меньше ошибок. |
| **Repository** | Единая точка данных для UI: объединяет сеть и кэш, переводит любые ошибки в `AppException`. UI не знает про Dio. |
| **Controllers** | Состояние экранов (loading / success / error / cached / empty), логика пагинации и фильтров. |

## Запросы (Retrofit)

| № | Метод | Endpoint | Где используется |
|---|---|---|---|
| 1 | GET | `/posts?_page&_limit[&userId]` | список с пагинацией и фильтром |
| 2 | GET | `/posts/{id}` | обновление поста на экране деталей |
| 3 | GET | `/posts?userId=` | «Постов у автора» на экране деталей |
| 4 | GET | `/posts/{id}/comments` | комментарии |
| 5 | POST | `/posts` | создание поста |
| + | GET | `/users`, `/users/{id}` | фильтр по автору, форма, карточка автора |

## Состояния UI

* Список: `ListStatus {loading, success, error, empty}` + флаг `fromCache` (Cached)
  + **отдельное** `PageStatus {idle, loading, error, ended}` для подгрузки страницы
  + флаг `refreshing`. Форма создания и экран деталей имеют свои состояния —
  единого `isLoading` нет.

## Ошибки

`AppException` различает: нет соединения, таймаут, HTTP 4xx, HTTP 5xx, ошибка
JSON, неизвестная. Interceptor превращает `DioException` в `AppException`,
UI показывает `userMessage`, технические детали пишутся в `developer.log`.

## Пагинация и фильтры

* 10 постов на страницу, подгрузка при прокрутке, индикатор внизу.
* Страница не запрашивается дважды (`_requestedPages` + `PageStatus.loading`).
* Ошибка следующей страницы — сообщение и кнопка «Повторить», список остаётся.
* Смена автора увеличивает `_generation`: ответы на старые запросы игнорируются,
  данные не смешиваются.
* Поиск по заголовку и сортировка по ID — **локально по загруженным постам**
  (в UI под полем поиска написано явно).

## Кэш и офлайн

`PostCache` хранит JSON списка постов в SharedPreferences отдельно для
«все посты» и для каждого автора, а также локально созданные посты.

| Сценарий | Поведение |
|---|---|
| Первый запуск | Кэша нет → индикатор загрузки → данные с сервера → запись в кэш. |
| Повторное открытие | Сразу показан кэш (плашка «Показаны сохранённые данные. Обновляем…»), параллельно идёт запрос; после успеха список и кэш обновляются, плашка исчезает. |
| Нет интернета | Показан последний успешный результат с плашкой и текстом ошибки; данные не удаляются. Если кэша нет — экран ошибки с кнопкой «Повторить». |
| Pull-to-refresh | Повторный запрос первой страницы поверх текущих данных. |

## Создание поста

Валидация: title 5–100, body 10–1000, userId из списка. Кнопка блокируется на
время запроса. Показывается ответ сервера. JSONPlaceholder **не сохраняет** данные
и всегда возвращает `id = 101`, поэтому в список пост добавляется локально с
собственным id и пометкой «создан локально» (хранится в SharedPreferences).

## Тесты (`flutter test`)

1. JSON → Post
2. Post → JSON
3. Загрузка постов через репозиторий (+ кэш)
4. Ошибка сервера 500 (кэш сохраняется)
5. Фильтрация по автору / заголовку / сортировка
6. Защита от дублирующейся загрузки страницы
* POST через `http_mock_adapter` (без интернета)
* Некорректный JSON → `AppException(parsing)`
* Ошибка следующей страницы + retry, смена фильтра, офлайн с кэшем

## Приёмочные сценарии

- [ ] Первый запуск: список загружается с сервера
- [ ] Прокрутка: подгружается следующая страница без дубликатов
- [ ] Фильтр: посты выбранного автора
- [ ] Детали: пост и комментарии
- [ ] Создание: POST отправлен, результат показан
- [ ] Офлайн: кэшированные посты доступны без сети
- [ ] Ошибка: приложение не падает
- [ ] `flutter test`: все тесты проходят

## Сдача

* Скриншоты: `docs/screenshots/` (список, фильтр, детали, создание, офлайн, ошибка)
* Отчёт о тестах: вывод `flutter test` → `docs/test_report.txt`
#   s r s 8  
 