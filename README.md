# Godot Together
A plugin for real-time collaboration over the network for Godot Engine.

[Wiki & help](https://github.com/Wolfyxon/GodotTogether/wiki/) |
[Troubleshooting](https://github.com/Wolfyxon/GodotTogether/wiki/Troubleshooting) |
[Report bugs](https://github.com/wolfyxon/godotTogether/issues/) |
[Feature TODO list](https://github.com/wolfyxon/godotTogether/issues/1)

> [!CAUTION]
> This plugin allows for **remote code execution**.  
> Make sure to **never collaborate** with **people you don't FULLY trust**.
> 
> There's also a risk of your projects becoming corrupted so
> **always make backups** or/and **use version control** like **git**.

## Features
- Node property and type sync
- Tree changes (node add, remove, reparent)
- File sync
- Basic security via password, manual user approval and kicking
- 2D and 3D Avatars showing where each user is on the scene
- Optional auto updater (always asks for consent before installing and can be completely turned off)
- Can make you a sandwich

All sync features listed above happen constantly in real time!

## Installation
First create a folder called `addons` in your project's directory.

### Getting the plugin
1. Head into the [latest release](https://github.com/Wolfyxon/GodotTogether/releases/latest)
2. Download `GodotTogether.zip`
3. Extract the zip contents into your `addons` folder, under "GodotTogether".
4. Ensure the file structure looks like this
```
yourProject
|_ addons
  |_ GodotTogether
    |_ src
    |_ plugin.cfg
```

### Enabling 
1. Click on **Project** on the top-left toolbar.
2. Go to **Project settings**
3. Go to the **plugins** tab
4. Enable **Godot Together**

You're now good to go!

## Testing
To run unit tests, enable the plugin,
go to **settings** (inside the plugin) and use **run unit tests now** or **run unit tests on start**.

You will see results in the output console.

### Writing tests
To create a test:
1. Go to `src/scripts/tests.gd`.
2. Create a function called `test_your_test_name` and typehint its return value as `bool`
3. Return `true` or `false` based on if the test failed or succeeded, and use `printerr` to explain details of the error
4. Your test should now run
