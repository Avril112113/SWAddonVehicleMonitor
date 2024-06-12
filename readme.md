# VehMon
A stormworks addon library to draw stuff to a vehicle's monitor.  
This is still work in progress.  
See [addon/script.lua](addon/script.lua) for usage example.  

The only build tool tested is [SSSWTool](https://github.com/Avril112113/SSSWTool).  
Other build tools like LifeBoatAPI may not work due to `require()` differences, make an issue if you want a build tool to be supported.  

To use this library, add both `AddonVehicleMonitor/addon/vehmon` and `AddonVehicleMonitor/shared` to your require path.  
For SSSWTool, these would be added to the `src` list in `ssswtool.json`.  


## Details
VehMon uses many keypads and dials to communicate various data to/from the vehicle.  
There is a limit of 256 groups and 255 db values.  
Providing any values out of expected ranges may cause unexpected behavior or the vehicle to error (differing decimal precision is fine).  

Groups are a list of things to draw, whether they should be drawn and an offset.  
The range of `group_id` is limited to 0 to 255.  
Monitor coordinates (including width/height args) are limited to -2046 to 2048 with a precision of 0.125.  

DB values are either a number (double precision) or a string.  
The range of `db_idx` is limited to 0 to 255, note that 0 is used when no db value is to be used.  
The range of `db_idy` is limited to 0 to 255, note that Lua indices start at 1, in most cases 0 should not be used.  
The db is like a 2d array, where the `idx` refers to an array of values and the `idy` refers to the value in that array.  
For example, `DrawText` and `DrawTextBox` only take `idx` as an argument (the array), so `idy` refers to the position in the format string for the value.  


## Building
`./addon/` is built using [SSSWTool](https://github.com/Avril112113/SSSWTool)  
`./vehicle/` is built using [LifeBoatAPI](https://marketplace.visualstudio.com/items?itemName=NameousChangey.lifeboatapi)  
