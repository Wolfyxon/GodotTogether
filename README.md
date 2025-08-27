# Godot Together
[Wiki](https://github.com/Wolfyxon/GodotTogether/wiki/) |
[Troubleshooting](https://github.com/Wolfyxon/GodotTogether/wiki/Troubleshooting)

An **experimental** plugin for real-time collaboration over the network for Godot Engine.

> [!WARNING]
> This plugin is **not ready for use.**  
> Many important features have not are not implemented or are buggy.  
> You are also risking **breaking your project** so make sure to **make a backup**.
>
> See the [TODO list](https://github.com/wolfyxon/godotTogether/issues/1) to see the current progress.

> [!CAUTION]
> Never EVER join or host projects to people you don't trust.  
> Your project can be very easily stolen and someone can remotely execute malicious code with tool scripts. 

## Installation
First create a folder called `addons` in your project's directory.

## Getting the plugin
>[!NOTE]
> As the plugin is not fully released, you're going to download the **current state of development** which may be unstable. 

### With Git (recommended)
Open the terminal in your `addons` folder, then run:
```
git clone https://github.com/Wolfyxon/GodotTogether.git
```

### Manual download

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

## Enabling 
1. Click on **Project** on the top-left toolbar.
2. Go to **Project settings**
3. Go to the **plugins** tab
4. Enable **Godot Together**
