# Godot Together
A **work in progress** plugin for real-time collaboration over the network for Godot Engine.

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

## Installation
First create a folder called `addons` in your project's directory.

### Getting the plugin
>[!NOTE]
> As the plugin is not fully released, you're going to download the **current state of development** which may be unstable. 

#### With Git (recommended)
Open the terminal in your `addons` folder, then run:
```
git clone https://github.com/Wolfyxon/GodotTogether.git
```

Then proceed to the [enabling section](#enabling).

#### Manual download

1. [Download the source code](https://github.com/Wolfyxon/GodotTogether/archive/refs/heads/main.zip) zip.
2. Extract the zip contents into your `addons` folder.
3. Rename `GodotTogether-main` to `GodotTogether`. IMPORTANT!!!

The structure should look like this
```
yourProject
|_ addons
  |_ GodotTogether
    |_ src
      |_ scripts
      |_ img
      |_ scenes
```

### Enabling 
1. Click on **Project** on the top-left toolbar.
2. Go to **Project settings**
3. Go to the **plugins** tab
4. Enable **Godot Together**
