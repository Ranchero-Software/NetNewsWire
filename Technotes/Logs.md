# Logs

`RSCore` contains a protocol called `Logging`. Classes and Structs that conform to `Logging` have a `logger` variable that the Class or Struct can use instead of importing `os.log` and creating a `var log = Logger(..)` variable.

Example:

```swift

import Foundation
import RSCore

class Sample: Logging {

    init() {
        logger.debug("Init")
    }
}
```
