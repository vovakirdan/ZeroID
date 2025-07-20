# Руководство по системе цветов ZeroID

## Обзор

Система цветов ZeroID основана на дизайне из фото и поддерживает светлую и темную темы с яркими зелеными/бирюзовыми градиентами.

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
- `Color.accentColor` - акцентный цвет (яркий зеленый/бирюзовый)

### Градиентные цвета
- `Color.gradientStart` - начало градиента (яркий зеленый)
- `Color.gradientEnd` - конец градиента (яркий бирюзовый)
- `Color.primaryGradient` - готовый градиент для кнопок и акцентов

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

### Кнопки с градиентами
```swift
// Основная кнопка с градиентом
Button("Действие") { }
    .background(Color.primaryGradient)
    .foregroundColor(.white)

// Вторичная кнопка
Button("Отмена") { }
    .background(Color.surfaceSecondary)
    .foregroundColor(.white)
```

### Градиенты для иконок
```swift
Image(systemName: "shield.fill")
    .foregroundStyle(Color.primaryGradient)
```

## Темы

### Темная тема (основная)
- **Основной фон**: темно-синий/бирюзовый (#0A0F14)
- **Текст**: белый (#FFFFFF)
- **Акцент**: яркий зеленый/бирюзовый градиент
- **Карточки**: темно-серый с синим оттенком (#191E23)
- **Границы**: темно-серый (#2D2D2D)
- **Приглушенный текст**: светло-серый (#A6A6A6)

### Светлая тема
- **Основной фон**: белый (#FFFFFF)
- **Текст**: темно-серый (#0D0D0D)
- **Акцент**: зеленый/бирюзовый градиент
- **Карточки**: светло-серый (#F5F5F5)
- **Границы**: светло-серый (#E9E9E9)
- **Приглушенный текст**: серый (#787878)

## Градиенты

### PrimaryGradient
Основной градиент приложения, используемый для:
- Кнопок действий
- Логотипа
- Иконок в карточках
- Акцентных элементов

```swift
// Автоматически создается градиент от зеленого к бирюзовому
Color.primaryGradient
```

### Настройка градиентов
```swift
// Создание кастомного градиента
LinearGradient(
    colors: [Color.gradientStart, Color.gradientEnd],
    startPoint: .leading,
    endPoint: .trailing
)

// Радиальный градиент
RadialGradient(
    colors: [Color.gradientStart, Color.gradientEnd],
    center: .center,
    startRadius: 0,
    endRadius: 100
)
```

## Рекомендации

1. **Всегда используйте семантические цвета** вместо хардкода
2. **Тестируйте в обеих темах** - светлой и темной
3. **Используйте градиенты для акцентов** - кнопки, логотип, важные элементы
4. **Придерживайтесь единообразия** в использовании цветов
5. **Используйте контрастные цвета** для текста и фона

## Добавление новых цветов

1. Создайте Color Set в Assets.xcassets
2. Добавьте поддержку светлой и темной темы
3. При необходимости добавьте алиас в `Colors.swift`
4. Обновите документацию

## Примеры использования в компонентах

### PrimaryButton
```swift
Button(action: action) {
    HStack(spacing: 8) {
        Text(title)
            .fontWeight(.semibold)
        Image(systemName: "arrow.right")
            .font(.body)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.primaryGradient)
    .foregroundColor(.white)
    .cornerRadius(14)
}
```

### InfoCard
```swift
HStack(spacing: 16) {
    Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(Color.primaryGradient)
        .frame(width: 40, height: 40)
    
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
        Text(description)
            .font(.caption)
            .foregroundColor(Color.textSecondary)
    }
    
    Spacer()
}
.padding(16)
.background(Color.surfaceSecondary)
.cornerRadius(12)
``` 