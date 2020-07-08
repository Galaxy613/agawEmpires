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

## Gameplay
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

### Joining

When you log in, you should see a map in front of you. You need to manually join the game by typing `/join`. TODO explain selecting preferr'd research.

### Sending Fleets

TODO

### Research

There are 6 different research fields, each apply to some aspect of your empire and its ships.

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
