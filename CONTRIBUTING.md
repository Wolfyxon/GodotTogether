# Guide to contributing to the project

Here are things you can do to contribute to the development of Godot Together.

- [Bugs and suggestions](#bugs-and-suggesions)
- [Writing code](#writing-code)
	- [Rules](#rules)
		- [Code style](#code-style)
		- [Typing](#typing)

## Bugs and suggesions
If you've found a bug or would like to suggest a change or a new feature, you can use [issues](https://github.com/Wolfyxon/GodotTogether/issues).

## Writing code
If you'd like to contribute to the project directly by writing code, first [fork the repository](https://github.com/Wolfyxon/GodotTogether/fork).

After that, you can apply changes to your fork.

When you're done, open a pull request and your changes will be reviewed for merging.
Make sure your pull request contains a clear description or title. 

### Rules
#### Code style
The [default GDScript style](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) is used in the project.

#### Typing
All variables, function return values and function arguments must have types assigned to them.

For example:
```gdscript
class_name Person

var name := "Anonymous"
var age: int

func greet(person) -> String:
	return "Hello, %s. My name is %s" % [person.name, name]

```