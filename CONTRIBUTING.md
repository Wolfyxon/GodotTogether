# Guide to contributing to the project

Here are things you can do to contribute to the development of Godot Together.

- [Bugs and suggestions](#bugs-and-suggesions)
- [Writing code](#writing-code)
	- [Creating a branch](#creating-a-branch)
 		- [Why?](#why)
   		- [I forgot to create a branch but I want to make a separate pull request](#i-forgot-to-create-a-branch-but-i-want-to-make-a-separate-pull-request)
     	- [Committing code](#committing-code) 
	- [Rules](#rules)
		- [Code style](#code-style)
		- [Typing](#typing)

## Bugs and suggesions
If you've found a bug or would like to suggest a change or a new feature, you can use [issues](https://github.com/Wolfyxon/GodotTogether/issues).

## Writing code
If you'd like to contribute to the project directly by writing code, first [fork the repository](https://github.com/Wolfyxon/GodotTogether/fork).
Then clone your forked repository locally:
```
git clone https://github.com/<your name>/GodotTogether.git
```

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

### Committing code
Use `git` (or the GitHub website, although that's very slow) to commit your changes.

Make sure to commit each change instead of making a one big commit so you can debug and see individual changes in your code.

❌ **Bad example**
```
git commit -m "General"
```
(has a lot of changes)

✅ **Good example**
```
git commit -m "Fixed some_function() not returning"
```
```
git commit -m "Added and using another_function()"
```
```
git commit -m "Fixed lag when X is enabled"
```
```
git commit -m "Cleanup"
```


### Rules
#### No AI generated code
AI tools such as ChatGPT can be useful tool for analysis, explanations, showing examples and debugging, but you cannot use it
to write entire sections of code with it.

You must have full understanding of the code you write.

#### Code style
The [default GDScript style](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) is used in the project.

However, you should use one line statements if using `return` to stop the function and if the condition is short.
```gdscript
func some_function():
	if something_is_bad: return
	if or_that: return

	do_stuff()
```

#### Typing
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
