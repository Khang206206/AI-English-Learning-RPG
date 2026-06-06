using Godot;
using System;
public partial class Checker : SceneTree {
    public override void _Initialize() {
        var img = Image.LoadFromFile("d:/AI-English-Learning-RPG/game-/assets/magic book/Turning_pages_left.png");
        GD.Print("Width: " + img.GetWidth() + ", Height: " + img.GetHeight());
        Quit();
    }
}
