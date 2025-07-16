# Godot Together
Make Godot games together in real time!

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
1. Create a folder called `addons` in your project's directory
2. [Download the repository's source code](https://github.com/Wolfyxon/GodotTogether/archive/refs/heads/main.zip)
3. Extract the contents into the `addons` folder: `yourProject/addons/GodotTogether`
4. Go to **Project** > **Project settings** in Godot
5. Go to the **Plugins** tab
6. Enable **Godot Together**

## Showcase
TODO

## FAQ

### Why wasn't it published earlier?
Due to the high possibility of using this plugin to remotely execute code, I wanted it to be as secure as possible before publishing.
I also wanted it to be usable enough. 
However due to feedback I've decided to make it public despite not being ready.

I must admit that I was being lazy and unmotivated to work on it.

I also got a bit too excited for something that was just an experiment. 

### Is it possible to host a project without opening ports?
The server is hosted on your machine, not some centralized network, so you need to either open ports in your router, host the server on a VPS or use a virtual network such as [ZeroTier](https://zerotier.com).

So yes, it is possible with a virtual network. Don't worry it's very easy.

### How does it work?
It uses the Godot's built-in multiplayer functionality.

Each node's property is saved and then compared every frame to check if it changed. If it did, the change is sent to the host, which verifies the user who made the change, and then applies it and replicates it to other users.

### Why should I be so careful?
Godot allows you to execute scripts within the editor without needing to run the game.
Simply opening a malicious project could get you hacked.
