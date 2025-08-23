# Math and Code Streaming Test

Here's some text with math expressions and code blocks to test streaming behavior.

First, let's have a simple equation: $E = mc^2$

Then a more complex display equation:
$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$

And some regular text that continues after the math.

Here's another inline equation $\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$ in the middle of a sentence.

Now let's test code highlighting with different languages:

```python
def fibonacci(n):
    """Calculate the nth Fibonacci number."""
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

# Test the function
for i in range(10):
    print(f"F({i}) = {fibonacci(i)}")
```

```javascript
function quickSort(arr) {
    if (arr.length <= 1) {
        return arr;
    }
    
    const pivot = arr[Math.floor(arr.length / 2)];
    const left = arr.filter(x => x < pivot);
    const middle = arr.filter(x => x === pivot);
    const right = arr.filter(x => x > pivot);
    
    return [...quickSort(left), ...middle, ...quickSort(right)];
}

console.log(quickSort([3, 6, 8, 10, 1, 2, 1]));
```

```swift
struct ContentView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Count: \(count)")
                .font(.largeTitle)
            
            Button("Increment") {
                count += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

This should test various scenarios for streaming content with proper syntax highlighting.