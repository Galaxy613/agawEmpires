# Overview
A multiplayer game of galatic conquest programmed in [BlitzMax Legacy](https://nitrologic.itch.io/blitzmax/).

## Disclaimer
It's an important to note issue #5, the security of this game is laughable and should only be played on a server you trust and with people you know.

# How to Play
Download a release and extract into an empty folder.

## Login
When you first start the client, it needs to generate it's settings. It will default to a 1280x720 window which you can change by editing `client-settings.ini`. Once it notifies you of this, it'll ask for a server IP. If you don't know it, go ahead and accept the default.

You will then be shown a login screen. If the top right of the screen has a green dot and a number above 0 that means you are connected to the server!

You will have to talk to the owner of the server to register an account, once you do, just type in your username and password. Click on "Username:" to highlight it so you can type, and then you can either press `Enter` to continue typing your password, or click on "Password:" to highlight it. Once you've typed your password, press `Enter` to log in.

## Game Screen
When you first join the server you won't see any systems. That's normal.

Take a look around the screen, the top bar of the screen, starting from the left, has:
 - `Player Chat`
   - This shows what people have recently said.
   - This will show everything that has been said since the server started.
 - `Empire News`
   - This shows messages only related to your empire.
   - Generally this will only show you messages of what happened while you were away, and what you just did.
 - Your current Fleet/System counts
   - Note: Fleet count is how many discrete fleets are currently moving around that you control, NOT how many total ships are owned by your empire!
   - Once you join it will also show how many total ships
 - Current Ship Building Time & Research Progress
   - Once you join this will show in the exact top middle of the screen.
 - Current ping/connection
   - This shows how many milliseconds round trip it takes to communicate with the server. Not really an issue since this game uses TCP.
   - It's bad when this turns red.

There's a number of commands you have to use the player chat for since this game is in alpha. Try pressing `Enter`, the player chat should become focused, try typing `/help` and press `Enter` again. It should tell you what commands there are. You can type `/help COMMAND_NAME` to get more information on each command.

### Navigating the Map

Hold down left click to pan around the map, you can use your mouse's scroll wheel or `+/-` keys to scroll in or out.

To the right of each system is a number which represents how many ships are in that system. There are no ship classes, the charactistics of your ships entirely depends on your empire's current research levels.

Additionally, there is no alliances in the game. At best you can make verbal agreements with other empires to not attack each other. But the game does not support sharing solar systems or fleets.

### Joining

When you log in, you should see a map in front of you. You need to manually join the game by typing `/join`.
You can optionally append a number at the end of that command to select your preferred research field.
Your preferred research field will start out with a boost to it when you start, and you will get a bonus when you research in that field.

- 0: RESEARCH
    -   You become a scientific prodigy, the speed at which you research increases.
- 1: SHIPBUILDING
    -   You become a master ship-builder, you produce ships faster.
- 2: FLEET WEAPONS
    -   You become a legendary weaponsmith, your ships deal more damage than others.
- 3: FUEL RANGE
    -   You become a amazing fuel tank designer, your ships have greater range than others.
- 4: RADAR RANGE
    -   You become a long-range sensor prodigy, you can see further than others.
- 5: FLEET SPEED
    -   You become a speed demon, your ships move faster than others.
- 6: PLANETARY DEFENSE
    -   You become a defense guru, your ships can sustain damage longer than others.

By default your empire's name will be `USERNAMEian Empire` you can rename it by using `/setEmpireName NEW_EMPIRE_NAME`.

### Sending Fleets

Sending ships is easy, just left click a system you own, then right click a system you want to send them to.

Each right click will select 1 ship to send, you can hold down `Shift` to add 5 ships per right click, or hold down `Ctrl` to add 100 ships per right click. You can right click the origin system to remove ships from the selection, and you can use the same `Shift/Ctrl` modifiers. Left click anywhere to just completely cancel the move.

Press `S` or click `(S)end ### ships` text to actually send the ships.

### Basic Gameplay

At the beginning you want to send at least a single ship to all nearby systems that have 0 native ships. Generally you want at least double the amount of native ships to make sure you will actually win.

### Research

There are 6 different research fields, each apply to some aspect of your empire and its ships.

- RESEARCH
    -   TODO explain it in more detail
- SHIPBUILDING
    -   TODO explain it in more detail
- FLEET WEAPONS
    -   TODO explain it in more detail
- FUEL RANGE
    -   TODO explain it in more detail
- RADAR RANGE
    -   TODO explain it in more detail
- FLEET SPEED
    -   TODO explain it in more detail
- PLANETARY DEFENSE
    -   TODO explain it in more detail

TODO explain each field

# How to Run a Server

This will be filled out later.

## Creating a Map

### Saving/Loading

Generally, the game will automatically save itself periodically. However you can change maps at any time, and nothing is stopping you from backing up the game file at any time.

## How to Register an Account

## Kicking and Banning

# Code Contributions

Contributions are welcome. Ideally you should create an issue before creating a pull request so we can talk about it.
