
SpriteID :: enum 
{
  WHITE;
  SKELETON;
  DIRT;
  DIRT_TOP;
  SAND;
  SAND_TOP;
  STONE;
  STONE_TOP;
  PICKAXE;
  BROKEN;
};

Sprite :: struct
{
  atlasOffset : Vector2;
  size : Vector2;
};

get_sprite :: (spriteID : SpriteID) -> Sprite
{
  sprite : Sprite = .{};

  if spriteID ==
  {
    case .WHITE;
      sprite.atlasOffset = .{0, 0};
      sprite.size = .{1, 1};

    case .SKELETON;
      sprite.atlasOffset = .{0, 16};
      sprite.size = .{32, 32};

    case .DIRT;
      sprite.atlasOffset = .{32, 8};
      sprite.size = .{8, 8};

    case .DIRT_TOP;
      sprite.atlasOffset = .{32, 0};
      sprite.size = .{8, 8};

    case .SAND;
      sprite.atlasOffset = .{40, 8};
      sprite.size = .{8, 8};

    case .SAND_TOP;
      sprite.atlasOffset = .{40, 0};
      sprite.size = .{8, 8};

    case .STONE;
      sprite.atlasOffset = .{48, 8};
      sprite.size = .{8, 8};

    case .STONE_TOP;
      sprite.atlasOffset = .{48, 0};
      sprite.size = .{8, 8};
    
    case .PICKAXE;
      sprite.atlasOffset = .{32, 16};
      sprite.size = .{16, 16};
    
    case .BROKEN;
      sprite.atlasOffset = .{56, 0};
      sprite.size = .{8, 8};

  }

  return sprite;
}