# Monkeys Raaassh

Roblox Multiplayer Survior / Bullet Heaven Game</br>
-[Released on Roblox](https://www.roblox.com/games/95975992291805/Monkeys-Raaassh)

## Monkey Tribe Rush 2

-[Monkey Tribe Rush](https://github.com/BarbasOyun/MonkeyTribeRush)</br>
-Raaassh = Monkey Tribe Rush 2</br>

-Monkey Tribe Rush = Custom Architecture</br>
-Monkeys Raaassh use a new project Architecture = Knit, Roact and Rodux</br>

## Features

The project feature :</br>
-Functional Programming</br>
-Per Stage Procedural Map generation -> Node base (2D Collision Detection + Solving)</br>
-WIP ECS for performance and defining behaviors using composition</br>
-Object Pooling -> PoolService</br>
-Auto target + Auto attacks system</br>
-Weapons definition</br>
-Players Total Stats calculated from 2 "Power System" (Meta Upgrades + Augments)</br>

## GameDesign

I'm mostly a Programmer but I'm also interested in GameDesign</br>

### Core Loop

The core loop of the game is the standard of the survivor genre :</br>
1] from Hub (or menus) start a Game</br>
2] Play, Get currency, loose, go back to Hub</br>
3] spend currency on meta upgrades, Loop</br>

### Multiplayer Survivor (Self Determination Theory (SDT))

I base my GameDesign on the [Self Determination Theory](https://en.wikipedia.org/wiki/Self-determination_theory).</br>
My simple explanation of it :</br>
Humans have 3 basic psychological needs : Autonomy, Competence and Relatedness, it is the satisfactions of those needs that we call fun.</br>
</br>
Video games have the potential to satisfy the 3 using different Design</br>
eg Increments and Automation to satisfy the need for Autonomy.</br>
</br>
Moneys Raaassh, like most Roblox game, focus on satisfying Autonomy (Survivor) and Relatedness (Multiplayer)</br>
(and to a lesser extent Competence).</br>

### Third Person Survivor

Most survivors feature a Top-Down view which often restrict movement to a 2D Plane,</br>
while interesting I like the third person approach of the game Mega Bonk,</br>
since every actions is used automatically the player have to focus mostly on movement/placement,</br>
third person camera allow for more verticality in the level (additonal dimension) and thus more movements possibility/options</br>

### Tempo & Incremental Loop

Instead of a Flat 20 minute timer like Vampire Survivors I went for a Infinite Enemy Scaling (Global Enemy Level).</br>
The Global Enemy Level define the difficulty, it is incremented by the Game timer and cannot be too far from the Stage Nbr</br>
The game is based on a simple structure :</br>
Killing enemies (Robots) to gain tempo, spend this tempo to destroy buildings and get bananas (Meta Upgrades currency),</br>
until players cannot keep up with the Global Enemy Level tempo and all die</br>

### Skill System Design

-WIP

## To Go Further

The Project still need some work :</br>
-Cleaning up the Project</br>
-Make Item, Weapons, Enemy Configuration easier</br>
-Proper Unit System</br>

Future Features :</br>
-Skill System</br>
-Status System</br>
-Enemies Modifier</br>
-Weapons Skins</br>

## Game Images

![icon](assets/Icon.png)
![image1](assets/Thumbnail_01.png)
![image2](assets/Thumbnail_02.png)
