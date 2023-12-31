FPS = 60

def spawn_target(args)
  size = 64
  {
    x: rand(args.grid.w * 0.4) + args.grid.w * 0.6,
    y: rand(args.grid.h - size * 2) + size,
    w: size,
    h: size,
    path: 'sprites/target.png',
  }
end

def fire_input?(args)
  args.inputs.keyboard.key_down.z ||
    args.inputs.keyboard.key_down.j ||
    args.inputs.controller_one.key_down.a
end

def handle_player_movement(args)
  if args.inputs.left
    args.state.player.x -= args.state.player.speed
  elsif args.inputs.right
    args.state.player.x += args.state.player.speed
  end

  if args.inputs.up
    args.state.player.y += args.state.player.speed
  elsif args.inputs.down
    args.state.player.y -= args.state.player.speed
  end

  if args.state.player.x +  args.state.player.w > args.grid.w
    args.state.player.x = args.grid.w - args.state.player.w
  end

  if args.state.player.x < 0
    args.state.player.x = 0
  end

  if args.state.player.y + args.state.player.h > args.grid.h
    args.state.player.y = args.grid.h - args.state.player.h
  end

  if args.state.player.y < 0
    args.state.player.y = 0
  end
end

def goto_gameplay_scene(args)
  args.audio[:music].paused = false
  args.state.score = 0
  args.state.timer = 30 * FPS
  args.state.player = {
    x: 120,
    y: 280,
    w: 100,
    h: 80,
    speed: 12,
  }
  args.state.fireballs = []
  args.state.targets = [
    spawn_target(args), spawn_target(args), spawn_target(args)
  ]
  args.state.scene = "gameplay"
end

def title_tick args
  if fire_input?(args)
    goto_gameplay_scene(args)
    return
  end

  labels = []
  labels << {
    x: 40,
    y: args.grid.h - 40,
    text: "Target Practice",
    size_enum: 6,
  }
  labels << {
    x: 40,
    y: args.grid.h - 88,
    text: "Hit the targets!",
  }
  labels << {
    x: 40,
    y: args.grid.h - 120,
    text: "by YOU",
  }
  labels << {
    x: 40,
    y: 120,
    text: "Arrows or WASD to move | Z or J to fire | gamepad works too",
  }
  labels << {
    x: 40,
    y: 80,
    text: "Fire to start",
    size_enum: 2,
  }
  args.outputs.labels << labels

  args.state.title_player ||= {
    x: 120,
    y: 280,
    w: 100,
    h: 80,
  }
  player_sprite_index = 0.frame_index(count: 6, hold_for: 8, repeat: true)
  args.state.title_player.path = "sprites/misc/dragon-#{player_sprite_index}.png"
  args.outputs.sprites << args.state.title_player
end

HIGH_SCORE_FILE = "high-score.txt"
def game_over_tick(args)
  args.state.high_score ||= args.gtk.read_file(HIGH_SCORE_FILE).to_i

  args.state.timer -= 1

  if !args.state.saved_high_score && args.state.score > args.state.high_score
    args.gtk.write_file(HIGH_SCORE_FILE, args.state.score.to_s)
    args.state.saved_high_score = true
  end

  labels = []
  labels << {
    x: 40,
    y: args.grid.h - 40,
    text: "Game Over!",
    size_enum: 10,
  }
  labels << {
    x: 40,
    y: args.grid.h - 90,
    text: "Score: #{args.state.score}",
    size_enum: 4,
  }

  if args.state.score > args.state.high_score
    labels << {
      x: 260,
      y: args.grid.h - 90,
      text: "New high-score!",
      size_enum: 3,
    }
  else
    labels << {
      x: 260,
      y: args.grid.h - 90,
      text: "Score to beat: #{args.state.high_score}",
      size_enum: 3,
    }
  end

  labels << {
    x: 40,
    y: args.grid.h - 132,
    text: "Fire to restart",
    size_enum: 2,
  }
  args.outputs.labels << labels

  if args.state.timer < -30 && fire_input?(args)
    goto_gameplay_scene(args)
    return
  end
end

def gameplay_tick(args)
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: args.grid.w,
    h: args.grid.h,
    r: 92,
    g: 120,
    b: 230,
  }

  hold_for = if args.inputs.left || args.inputs.right || args.inputs.up || args.inputs.down
    8
  else
    16
  end
  player_sprite_index = 0.frame_index(count: 6, hold_for: hold_for, repeat: true)
  args.state.player.path = "sprites/misc/dragon-#{player_sprite_index}.png"

  args.state.timer -= 1

  if args.state.timer == 0
    args.audio[:music].paused = true
    args.outputs.sounds << "sounds/game-over.wav"
    args.state.scene = "game_over"
    return
  end

  handle_player_movement(args)

  if fire_input?(args)
    args.outputs.sounds << "sounds/fireball.wav"
    args.state.fireballs << {
      x: args.state.player.x + args.state.player.w - 12,
      y: args.state.player.y + 10,
      w: 32,
      h: 32,
      path: 'sprites/fireball.png',
    }
  end

  args.state.fireballs.each do |fireball|
    fireball.x += args.state.player.speed + 2

    if fireball.x > args.grid.w
      fireball.dead = true
      next
    end

    args.state.targets.each do |target|
      if args.geometry.intersect_rect?(target, fireball)
        args.outputs.sounds << "sounds/target.wav"
        target.dead = true
        fireball.dead = true
        args.state.score += 1
        args.state.targets << spawn_target(args)
      end
    end
  end

  args.state.targets.reject! { |t| t.dead }
  args.state.fireballs.reject! { |f| f.dead }

  args.outputs.sprites << [args.state.player, args.state.fireballs, args.state.targets]

  labels = []
  labels << {
    x: 40,
    y: args.grid.h - 40,
    text: "Score: #{args.state.score}",
    size_enum: 4,
  }
  labels << {
    x: args.grid.w - 40,
    y: args.grid.h - 40,
    text: "Time Left: #{(args.state.timer / FPS).round}",
    size_enum: 2,
    alignment_enum: 2,
  }
  args.outputs.labels << labels
end

def tick args
  if args.state.tick_count == 1
    args.audio[:music] = { input: "sounds/flight.ogg", looping: true }
  end

  args.state.scene ||= "title"

  send("#{args.state.scene}_tick", args)
end
