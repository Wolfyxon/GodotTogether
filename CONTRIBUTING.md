# Guide to contributing to the project

Here are things you can do to contribute to the development of Godot Together.

- [Bugs and suggestions](#bugs-and-suggesions)
- [Writing code](#writing-code)
	- [Creating a branch](#creating-a-branch)
 		- [Why?](#why)
   		- [I forgot to create a branch but I want to make a separate pull request](#i-forgot-to-create-a-branch-but-i-want-to-make-a-separate-pull-request)
	- [Rules](#rules)
 		- [No AI generated code](#no-ai-generated-code) 
		- [Code style](#code-style)
		- [Type hints](#type-hints)
        - [Use class prefixes](#use-class-prefixes)
        - [RPC functions](#rpc-functions)
        - [Explanation comments](#explanation-comments)
        - [No author comments](#no-author-comments)
        - [Testing](#testing)

## Bugs and suggestions
If you've found a bug or would like to suggest a change or a new feature, you can use [issues](https://github.com/Wolfyxon/GodotTogether/issues).

## Writing code
If you'd like to contribute to the project directly by writing code, first [fork the repository](https://github.com/Wolfyxon/GodotTogether/fork).
Then clone your forked repository locally:
```
git clone https://github.com/<your name>/GodotTogether.git
```

## Repository already cloned
If you have already cloned the repository, make sure to pull the recent changes **before you start coding**.
```
git pull
```
If you use branches, you will need to do this on each of them. 

### Creating a branch
Then I **highly** recommend you create a separate branch instead of committing to `main`, so you can submit multiple pull requests.

```
git checkout -b my-epic-patch
```
Pushing your branch
```
git push -u origin my-epic-patch
```
(`-u` sets the default push target and is optional. After it's been used once, you can just use `git push`)

#### Why? 
If there's an issue with one part of your code but other work properly, they can already be merged and the broken part can wait until it's fixed.

#### I forgot to create a branch but I want to make a separate pull request
Simply branch off an older commit. See:
```
git log
```
To find the hash (for example a1Cx10dk01d01d), then use
```
git checkout -b <name of your new branch> <commit hash>
```
To branch off that older commit.

### Rules
#### No AI generated code
AI tools such as ChatGPT can be useful tools for analysis, explanations, showing examples and debugging, but you cannot use them
to write entire sections of code with it as you're not the person who writes the code then.

You must have full understanding of the code you write and thus using AI generated code in this project is not allowed.

#### Code style
The [default GDScript style](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) is used in the project.

The general rules include:
- `snake_case_naming` for variables and functions
- `UpperCamelCaseNaming` for classes
- Newline separations between sections of code 

However, you should use one line statements if using `return` to stop the function and if the condition is short.
```gdscript
func some_function():
	if something_is_bad: return
	if or_that: return

	do_stuff()
```

#### Type hints
All variables, function return values and function arguments must have types assigned to them.

For example:
```gdscript
class_name Person

var name := "Anonymous"
var age: int

func greet(other_person: Person) -> String:
	return "Hello, %s. My name is %s" % [other_person.name, name]
```

For more info see [the Godot's documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html).

#### Use class prefixes
All defined classes should start with the `GDT` prefix to make sure the plugin doesn't conflict with users' projects.

❌ **Bad**:
```gdscript
class_name User
```

✅ **Good**:
```gdscript
class_name GDTUser
```

#### RPC functions
Always properly configure RPC functions. Use `"reliable"` to make sure it's always received.  
If it's not critical to the plugin (like avatar position updates), use `"unreliable"`, or "unreliable_ordered".  
Unreliable functions save on performance.

```gdscript
@rpc("authority", "reliable")
func i_am_very_important():

@rpc("authority", "unreliable")
func would_be_nice_if_you_call_me_but_its_fine()

```

If a function is only meant to be received by the server, prefix it with `_c2s_` (means client to server),
and if it's only meant to be received by clients from the server, use `_s2c` (server to client).
If an RPC function is called in both cases, do not prefix it.

Always properly use `"authority"` and `"any_peer"`, and validate everything to ensure security.

```gdscript
@rpc("authority", "reliable")
func i_can_be_called_on_clients_by_the_server_and_scripts()

@rpc("any_peer", "reliable")
func everyone_calls_me()

@rpc("any_peer", "reliable")
func _c2s_say_something_to_the_server():
	if not main.server.validate_c2s(): # Server is not running! Function got called client->client 
		return

	if not main.server.caller_has_permission(GodotTogether.Permission.SOMETHING):
		return

```

#### Explanation comments
If a piece of code is not obvious for what it does or why it is there, you should make a comment explaining it.

On the other hand, do not make comments for self explanatory code.


❌ **Bad**:
```gdscript
static func get_node_in_scene(node_path: String, scene_path: String) -> Node:
	# Iterate through all scene roots
	for scene in EditorInterface.get_open_scene_roots():
		if scene.scene_file_path == scene_path: # Check if the scene has the given path
			return scene.get_node_or_null(node_path) # Get and return the target node
	
	return
```
```gdscript
	await get_tree().process_frame
	
	if node.is_inside_tree() and node_path == scene.get_path_to(node):
		return
```
✅ **Good**:
```gdscript
	# Do not delete the node if it was reparented into a node with the same path
	# This is the case for node replacements (class changes).
	# This fixes children of replaced nodes disappearing, while also preserving reparenting.
	await get_tree().process_frame # Needs to wait a frame
	
	if node.is_inside_tree() and node_path == scene.get_path_to(node):
		return
```

#### No author comments
Please don't add comments saying which features were made by you.

If you make a significant contribution, you will be put in the special thanks section in the plugin's about menu.
Also most likely you and your PR will be mentioned on the release page (when a stable version is released).

```gdscript
# Some feature by XYZ
func some_function():
	...
```

#### Testing
Your changes must obviously be manually tested before opening a pull request.

You must also run **unit tests**, which validate values returned by various functions based on the expected result and also validate the plugin's configuration.

To run them, enable the plugin, go to the **settings** and use **run unit tests now** or enable **run unit tests on start**.
After that, check the console.
