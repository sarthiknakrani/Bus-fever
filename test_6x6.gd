extends SceneTree

func _init():
    var board_w = 6
    var board_h = 6
    # Let's map out 12 buses on 6x6.
    # Total cells: 36. 12 buses * 2 = 24 cells.
    
    # 4 Red, 4 Blue, 4 Yellow
    var c = [
        # Example 6x6 packed layout:
        # Col 0: v1(0,1)->UP, v2(0,4)->DOWN
        {"id": 1, "code": "v1", "col": "red", "pos": Vector2i(0, 1), "dir": 0},
        {"id": 2, "code": "v2", "col": "blue", "pos": Vector2i(0, 4), "dir": 1},
        
        # Col 1: v3(1,1)->UP, v4(1,4)->DOWN
        {"id": 3, "code": "v3", "col": "yellow", "pos": Vector2i(1, 1), "dir": 0},
        {"id": 4, "code": "v4", "col": "red", "pos": Vector2i(1, 4), "dir": 1},
        
        # Row 2 (middle): v5(3,2)->LEFT, v6(5,2)->RIGHT
        {"id": 5, "code": "v5", "col": "blue", "pos": Vector2i(3, 2), "dir": 2},
        {"id": 6, "code": "v6", "col": "yellow", "pos": Vector2i(5, 2), "dir": 3},
        
        # Row 3 (middle): v7(2,3)->LEFT, v8(4,3)->RIGHT
        {"id": 7, "code": "v7", "col": "red", "pos": Vector2i(2, 3), "dir": 2},
        {"id": 8, "code": "v8", "col": "blue", "pos": Vector2i(4, 3), "dir": 3},
        
        # Col 4: v9(4,1)->UP
        {"id": 9, "code": "v9", "col": "yellow", "pos": Vector2i(4, 1), "dir": 0},
        
        # Col 5: v10(5,1)->UP, v11(5,4)->DOWN
        {"id": 10, "code": "v10", "col": "red", "pos": Vector2i(5, 1), "dir": 0},
        {"id": 11, "code": "v11", "col": "blue", "pos": Vector2i(5, 4), "dir": 1},
        
        # Col 4: v12(4,4)->DOWN
        {"id": 12, "code": "v12", "col": "yellow", "pos": Vector2i(4, 4), "dir": 1}
    ]
    
    # Cells used:
    # Col 0: (0,1), (0,2) & (0,4), (0,3)
    # Col 1: (1,1), (1,2) & (1,4), (1,3)
    # Row 2: (3,2), (4,2) & (5,2), (4,2) -> WAIT, (4,2) conflict! v5 and v6.
    
    quit()
