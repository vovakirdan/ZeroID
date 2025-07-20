# Руководство по системе цветов ZeroID

## Обзор

Система цветов ZeroID основана на дизайн-системе из веб-версии приложения и поддерживает светлую и темную темы.

## Основные цвета

### Семантические цвета
- `Color.background` - основной фон приложения
- `Color.foreground` - основной цвет текста
- `Color.card` - фон карточек и модальных окон
- `Color.primary` - основной цвет для кнопок и акцентов
- `Color.secondary` - вторичный цвет для фонов
- `Color.muted` - приглушенный цвет для фонов
- `Color.mutedForeground` - приглушенный цвет текста
- `Color.border` - цвет границ
- `Color.destructive` - цвет для ошибок и удаления
- `Color.accentColor` - акцентный цвет (синий)

### Удобные алиасы

#### Цвета для текста
- `Color.textPrimary` - основной текст
- `Color.textSecondary` - вторичный текст
- `Color.textMuted` - приглушенный текст

#### Цвета для фонов
- `Color.surfacePrimary` - основной фон
- `Color.surfaceSecondary` - вторичный фон
- `Color.surfaceMuted` - приглушенный фон

#### Цвета для границ
- `Color.borderPrimary` - основные границы
- `Color.borderSecondary` - вторичные границы

#### Цвета для состояний
- `Color.success` - успех (зеленый)
- `Color.warning` - предупреждение (оранжевый)
- `Color.error` - ошибка (красный)
- `Color.info` - информация (синий)

## Использование

### Текст
```swift
Text("Основной текст")
    .foregroundColor(Color.textPrimary)

Text("Вторичный текст")
    .foregroundColor(Color.textSecondary)

Text("Приглушенный текст")
    .foregroundColor(Color.textMuted)
```

### Фоны
```swift
Rectangle()
    .fill(Color.surfacePrimary) // Основной фон

RoundedRectangle(cornerRadius: 12)
    .fill(Color.surfaceSecondary) // Фон карточки

Rectangle()
    .fill(Color.surfaceMuted) // Приглушенный фон
```

### Границы
```swift
Rectangle()
    .stroke(Color.borderPrimary, lineWidth: 1)

RoundedRectangle(cornerRadius: 8)
    .stroke(Color.borderSecondary, lineWidth: 0.5)
```

### Кнопки
```swift
// Основная кнопка
Button("Действие") { }
    .background(Color.accentColor)
    .foregroundColor(Color.primary)

// Вторичная кнопка
Button("Отмена") { }
    .background(Color.secondary)
    .foregroundColor(Color.accentColor)
```

## Темы

### Светлая тема
- Основной фон: белый (#FFFFFF)
- Текст: темно-серый (#0D0D0D)
- Акцент: синий (#F09961)
- Границы: светло-серый (#E9E9E9)

### Темная тема
- Основной фон: темно-серый (#0D0D0D)
- Текст: светло-серый (#FAFAFA)
- Акцент: голубой (#F0C27A)
- Границы: темно-серый (#2D2D2D)

## Рекомендации

1. **Всегда используйте семантические цвета** вместо хардкода
2. **Тестируйте в обеих темах** - светлой и темной
3. **Используйте контрастные цвета** для текста и фона
4. **Придерживайтесь единообразия** в использовании цветов

## Добавление новых цветов

1. Создайте Color Set в Assets.xcassets
2. Добавьте поддержку светлой и темной темы
3. Добавьте цвет в `Colors.swift`
4. Обновите документацию 