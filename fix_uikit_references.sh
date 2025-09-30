#!/bin/bash

echo "🔧 Fixing UIKit references for cross-platform compatibility..."

# Fix UIColor.systemBackground
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.systemBackground)/Color(.gray.opacity(0.05))/g'

# Fix UIColor.systemGray6
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.systemGray6)/Color.gray.opacity(0.1)/g'

# Fix UIColor.systemGray5
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.systemGray5)/Color.gray.opacity(0.2)/g'

# Fix UIColor.systemGroupedBackground
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.systemGroupedBackground)/Color.gray.opacity(0.05)/g'

# Fix UIColor.secondarySystemGroupedBackground
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.secondarySystemGroupedBackground)/Color.gray.opacity(0.08)/g'

# Fix UIColor.tertiarySystemGroupedBackground
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.tertiarySystemGroupedBackground)/Color.gray.opacity(0.12)/g'

# Fix UIColor.separator
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs sed -i '' 's/Color(UIColor\.separator)/Color.gray.opacity(0.3)/g'

echo "✅ UIKit references fixed!"