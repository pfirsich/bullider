# Bullider
Bullider is a special purpose collision detection library for bullet hell games.

You can use bullider as shown in the demo program [main.lua](main.lua), but it's pretty small, so it can also just serve as an inspiration for how you want do to collision detection in your bullet hell game.

## It's Good At
* Creating and destroying many objects continuously (it should create zero garbage)
* Checking a couple objects against many others
* Checking collision for fast moving objects (does continuous collision detection)
* It's pretty fast

## It's Bad At
* Checking many objects against many others (e.g. everything against everything)
* Collision response (it doesn't do that at all)
* Checking anything other than spheres

## To Do
* Implement a broad phase? I don't think it's necessary and I'm not sure if it's helpful at all (there is of course an extra cost).
* Try out different ways to keep track of active objects. The current approach was chosen, because it is very simple and seems to have no obvious downsides, but in the `double_linked_list` branch you can see an approach where each collider will keep track of the next and previous active collider. The extra bookkeeping is significant, but for some reason it's a good bit faster (by a factor 3 or so). Sadly it's very clear that the approach is complex and that's also why it's error prone and not something I want to maintain. I would like to find out why exactly it's this much faster while not seeming like it at all.
* Handle groups better. I'm not sure if the current approach is as useful as I think. A version that takes only a single group as an argument to `getCollisions` is noticably faster. I also tried out a bitmask version (see `bitmask_groups` branch), which is a bit faster, but in my opinion less nice to use.

## Demo Program
You can press the buttons specified in brackets in the debug text to switch stuff around.
Here is a video with some hint on the performance (V-Sync is enabled, so the time steps are large enough for the frame advance to show actual capsule shapes instead of sligtly smudged circles) (running on an i5 6600, 16GB RAM):

[Video](https://youtu.be/NYlCBpUMp3I)