import re

files_to_fix = [
    "/Users/muhammedanshid/Desktop/car_wash_mobile/lib/screens/invoice_create_screen.dart",
    "/Users/muhammedanshid/Desktop/car_wash_mobile/lib/screens/invoice_view_screen.dart",
    "/Users/muhammedanshid/Desktop/car_wash_mobile/lib/screens/schemes_screen.dart"
]

def add_currency_getter(content):
    if "String get currencySymbol {" not in content:
        getter = """
  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
  }
"""
        # find the state class definition to inject it
        match = re.search(r'class _[a-zA-Z]+State extends State<[a-zA-Z]+> \{', content)
        if match:
            idx = match.end()
            content = content[:idx] + getter + content[idx:]
    return content

for file_path in files_to_fix:
    with open(file_path, 'r') as f:
        content = f.read()
    
    content = add_currency_getter(content)
    
    # replace '₹' with '$currencySymbol'
    content = content.replace("'₹'", "'$currencySymbol'")
    content = content.replace("'₹ ", "'$currencySymbol ")
    content = content.replace("₹$", "$currencySymbol$")
    content = content.replace("₹${", "$currencySymbol${")
    content = content.replace("-₹${", "-$currencySymbol${")
    content = content.replace("(₹)", "($currencySymbol)")
    content = content.replace("(₹${", "($currencySymbol${")
    
    with open(file_path, 'w') as f:
        f.write(content)
print("Flutter string replacements done.")
