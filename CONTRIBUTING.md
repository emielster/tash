# Contributing to Tash

First of all, thanks a lot for taking the time to contribute :)

We are eager for contributions, so all contributions are welcome!


# Code style and avoiding naming collisions
POSIX shell does not have local variables. That means that:
```shell
# in tash.sh
my_function() {
	mode=0
	# do something with var...
}

# in an user's file of tash.sh, unaware of what is in tash.sh...
mode=1
my_function
echo $mode # 0 -- but what? I declared it as 1
```
is UB, even if it doesn't look like that. Shell variables are global, at all costs,
there is no such thing as automatic/local variables.

Using short names like `mode`, `item`, `name`, ... in functions is *readable*, but it is an invitation
to naming collisions.

To prevent this, please follow the Tash naming convention:

| type | prefix | example |
|------|--------|---------|
| external function | tash_* or [**none**\*](#information-about-none) | `tash_init`, `item` |
| internal function<sub>(i.e. from `tash.sh`)</sub> | tash__* | `tash__var_name`, `tash__scope_is_descendant_of` |
| framework variables | TASH_* (uppercase) | `TASH_SCOPE`, `TASH_MODE` |
| function/internal variables | TASH__* | `TASH__name`, `TASH__mode` |

<a name="information-about-none">*: This is because Tash is meant to be used as a testing framework, isolated from real source code. Therefore we can safely assume the user doesn't have any other functions named `item` already defined. Plus, having to type `tash_` everytime when you open up a new item is repetitive and exhausting. </a>




(coming soon)


