#!/usr/bin/env bash

# Sample project generator for git-checkpoints tests
# Creates realistic project files for testing

create_sample_project() {
    local project_type="${1:-web}"
    
    case "$project_type" in
        "web")
            create_web_project
            ;;
        "python")
            create_python_project
            ;;
        "node")
            create_node_project
            ;;
        *)
            echo "Unknown project type: $project_type"
            echo "Available types: web, python, node"
            exit 1
            ;;
    esac
}

create_web_project() {
    # HTML file
    cat > index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sample Web Project</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>Welcome to Sample Project</h1>
    </header>
    <main>
        <section id="content">
            <p>This is a sample web project for testing git-checkpoints.</p>
            <button id="clickMe">Click Me!</button>
        </section>
    </main>
    <script src="script.js"></script>
</body>
</html>
EOF

    # CSS file
    cat > styles.css <<'EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: Arial, sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f4f4f4;
}

header {
    background: #35424a;
    color: white;
    padding: 1rem 0;
    text-align: center;
}

main {
    max-width: 800px;
    margin: 2rem auto;
    padding: 0 1rem;
}

#content {
    background: white;
    padding: 2rem;
    border-radius: 5px;
    box-shadow: 0 0 10px rgba(0,0,0,0.1);
}

button {
    background: #35424a;
    color: white;
    padding: 10px 20px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    margin-top: 1rem;
}

button:hover {
    background: #2c3e50;
}
EOF

    # JavaScript file
    cat > script.js <<'EOF'
document.addEventListener('DOMContentLoaded', function() {
    const button = document.getElementById('clickMe');
    const content = document.getElementById('content');
    
    let clickCount = 0;
    
    button.addEventListener('click', function() {
        clickCount++;
        
        if (clickCount === 1) {
            content.innerHTML += '<p>Button clicked once!</p>';
        } else {
            content.innerHTML += `<p>Button clicked ${clickCount} times!</p>`;
        }
        
        // Change button color after 5 clicks
        if (clickCount >= 5) {
            button.style.background = '#e74c3c';
            button.textContent = 'Wow, many clicks!';
        }
    });
});
EOF

    echo "Created web project files: index.html, styles.css, script.js"
}

create_python_project() {
    # Main Python file
    cat > main.py <<'EOF'
#!/usr/bin/env python3
"""
Sample Python project for testing git-checkpoints
A simple calculator with basic operations
"""

import sys
from calculator import Calculator
from utils import validate_input, print_result

def main():
    """Main function to run the calculator"""
    print("Welcome to the Sample Calculator!")
    print("Available operations: add, subtract, multiply, divide")
    
    calc = Calculator()
    
    while True:
        try:
            operation = input("\nEnter operation (or 'quit' to exit): ").strip().lower()
            
            if operation == 'quit':
                print("Goodbye!")
                break
            
            if operation not in ['add', 'subtract', 'multiply', 'divide']:
                print("Invalid operation. Please try again.")
                continue
            
            num1 = validate_input("Enter first number: ")
            num2 = validate_input("Enter second number: ")
            
            if operation == 'add':
                result = calc.add(num1, num2)
            elif operation == 'subtract':
                result = calc.subtract(num1, num2)
            elif operation == 'multiply':
                result = calc.multiply(num1, num2)
            elif operation == 'divide':
                result = calc.divide(num1, num2)
            
            print_result(operation, num1, num2, result)
            
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()
EOF

    # Calculator module
    cat > calculator.py <<'EOF'
"""
Calculator module with basic arithmetic operations
"""

class Calculator:
    """A simple calculator class"""
    
    def add(self, a, b):
        """Add two numbers"""
        return a + b
    
    def subtract(self, a, b):
        """Subtract b from a"""
        return a - b
    
    def multiply(self, a, b):
        """Multiply two numbers"""
        return a * b
    
    def divide(self, a, b):
        """Divide a by b"""
        if b == 0:
            raise ValueError("Cannot divide by zero")
        return a / b
EOF

    # Utils module
    cat > utils.py <<'EOF'
"""
Utility functions for the calculator
"""

def validate_input(prompt):
    """Validate and convert user input to float"""
    while True:
        try:
            value = float(input(prompt))
            return value
        except ValueError:
            print("Please enter a valid number.")

def print_result(operation, num1, num2, result):
    """Print the calculation result in a formatted way"""
    symbols = {
        'add': '+',
        'subtract': '-',
        'multiply': '*',
        'divide': '/'
    }
    
    symbol = symbols.get(operation, '?')
    print(f"Result: {num1} {symbol} {num2} = {result}")
EOF

    # Requirements file
    cat > requirements.txt <<'EOF'
# No external dependencies for this simple project
# This file is here for demonstration purposes
EOF

    # Test file
    cat > test_calculator.py <<'EOF'
#!/usr/bin/env python3
"""
Simple tests for the calculator module
"""

import unittest
from calculator import Calculator

class TestCalculator(unittest.TestCase):
    
    def setUp(self):
        self.calc = Calculator()
    
    def test_add(self):
        self.assertEqual(self.calc.add(2, 3), 5)
        self.assertEqual(self.calc.add(-1, 1), 0)
    
    def test_subtract(self):
        self.assertEqual(self.calc.subtract(5, 3), 2)
        self.assertEqual(self.calc.subtract(0, 5), -5)
    
    def test_multiply(self):
        self.assertEqual(self.calc.multiply(3, 4), 12)
        self.assertEqual(self.calc.multiply(-2, 3), -6)
    
    def test_divide(self):
        self.assertEqual(self.calc.divide(10, 2), 5)
        self.assertEqual(self.calc.divide(7, 2), 3.5)
    
    def test_divide_by_zero(self):
        with self.assertRaises(ValueError):
            self.calc.divide(5, 0)

if __name__ == '__main__':
    unittest.main()
EOF

    echo "Created Python project files: main.py, calculator.py, utils.py, requirements.txt, test_calculator.py"
}

create_node_project() {
    # Package.json
    cat > package.json <<'EOF'
{
  "name": "sample-node-project",
  "version": "1.0.0",
  "description": "A sample Node.js project for testing git-checkpoints",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "node test.js",
    "dev": "node --watch index.js"
  },
  "keywords": ["sample", "nodejs", "git-checkpoints"],
  "author": "Test User",
  "license": "MIT",
  "dependencies": {},
  "devDependencies": {}
}
EOF

    # Main Node.js file
    cat > index.js <<'EOF'
const http = require('http');
const url = require('url');
const { Calculator } = require('./calculator');

const PORT = process.env.PORT || 3000;
const calc = new Calculator();

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const path = parsedUrl.pathname;
    const query = parsedUrl.query;
    
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'application/json');
    
    if (path === '/') {
        res.writeHead(200);
        res.end(JSON.stringify({
            message: 'Welcome to Sample Calculator API',
            endpoints: [
                '/add?a=1&b=2',
                '/subtract?a=5&b=3',
                '/multiply?a=4&b=3',
                '/divide?a=10&b=2'
            ]
        }));
        return;
    }
    
    const a = parseFloat(query.a);
    const b = parseFloat(query.b);
    
    if (isNaN(a) || isNaN(b)) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'Invalid parameters. Please provide a and b as numbers.' }));
        return;
    }
    
    try {
        let result;
        
        switch (path) {
            case '/add':
                result = calc.add(a, b);
                break;
            case '/subtract':
                result = calc.subtract(a, b);
                break;
            case '/multiply':
                result = calc.multiply(a, b);
                break;
            case '/divide':
                result = calc.divide(a, b);
                break;
            default:
                res.writeHead(404);
                res.end(JSON.stringify({ error: 'Endpoint not found' }));
                return;
        }
        
        res.writeHead(200);
        res.end(JSON.stringify({
            operation: path.substring(1),
            a: a,
            b: b,
            result: result
        }));
        
    } catch (error) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: error.message }));
    }
});

server.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
EOF

    # Calculator module
    cat > calculator.js <<'EOF'
class Calculator {
    add(a, b) {
        return a + b;
    }
    
    subtract(a, b) {
        return a - b;
    }
    
    multiply(a, b) {
        return a * b;
    }
    
    divide(a, b) {
        if (b === 0) {
            throw new Error('Cannot divide by zero');
        }
        return a / b;
    }
}

module.exports = { Calculator };
EOF

    # Simple test file
    cat > test.js <<'EOF'
const { Calculator } = require('./calculator');

function runTests() {
    const calc = new Calculator();
    let passed = 0;
    let failed = 0;
    
    function test(name, actual, expected) {
        if (actual === expected) {
            console.log(`✅ ${name}: PASS`);
            passed++;
        } else {
            console.log(`❌ ${name}: FAIL (expected ${expected}, got ${actual})`);
            failed++;
        }
    }
    
    function testError(name, fn, expectedError) {
        try {
            fn();
            console.log(`❌ ${name}: FAIL (expected error but none thrown)`);
            failed++;
        } catch (error) {
            if (error.message === expectedError) {
                console.log(`✅ ${name}: PASS`);
                passed++;
            } else {
                console.log(`❌ ${name}: FAIL (expected "${expectedError}", got "${error.message}")`);
                failed++;
            }
        }
    }
    
    console.log('Running Calculator Tests...\n');
    
    // Addition tests
    test('Add positive numbers', calc.add(2, 3), 5);
    test('Add negative numbers', calc.add(-2, -3), -5);
    test('Add mixed numbers', calc.add(-2, 3), 1);
    
    // Subtraction tests
    test('Subtract positive numbers', calc.subtract(5, 3), 2);
    test('Subtract negative numbers', calc.subtract(-5, -3), -2);
    
    // Multiplication tests
    test('Multiply positive numbers', calc.multiply(3, 4), 12);
    test('Multiply by zero', calc.multiply(5, 0), 0);
    
    // Division tests
    test('Divide positive numbers', calc.divide(10, 2), 5);
    test('Divide with decimal result', calc.divide(7, 2), 3.5);
    testError('Divide by zero', () => calc.divide(5, 0), 'Cannot divide by zero');
    
    console.log(`\nTest Results: ${passed} passed, ${failed} failed`);
    
    if (failed === 0) {
        console.log('🎉 All tests passed!');
        process.exit(0);
    } else {
        console.log('💥 Some tests failed!');
        process.exit(1);
    }
}

runTests();
EOF

    echo "Created Node.js project files: package.json, index.js, calculator.js, test.js"
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    create_sample_project "$@"
fi
