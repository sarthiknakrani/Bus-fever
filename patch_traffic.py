import re
with open("scripts/gameplay/departure_traffic_behavior.gd", "r") as f:
    content = f.read()

old_block = """				# other is ahead of us (to our right)
				if dist_x > 0 and dist_x < safe_gap:
					can_move = false
					blocking_id = other.vehicle_id
					min_dist = dist_x
				
				# other is behind us (to our left), approaching fast, and we are just merging
				if state == 1 and dist_x < 0 and dist_x > -safe_gap:
					if other.state == 2: # they are already driving straight
						can_move = false
						blocking_id = other.vehicle_id
						min_dist = dist_x"""

new_block = """				# other is ahead of us (to our right)
				if dist_x > 0 and dist_x < safe_gap:
					can_move = false
					blocking_id = other.vehicle_id
					min_dist = dist_x
				elif dist_x == 0.0 and other.vehicle_id < vehicle_id:
					can_move = false
					blocking_id = other.vehicle_id
					min_dist = dist_x
				
				# other is behind us (to our left), approaching fast, and we are just merging
				if state == 1 and dist_x < 0 and dist_x > -safe_gap:
					# Yield if they are already driving straight, or if they are also merging but have priority (lower ID)
					if other.state == 2 or (other.state == 1 and other.vehicle_id < vehicle_id):
						can_move = false
						blocking_id = other.vehicle_id
						min_dist = dist_x"""

content = content.replace(old_block, new_block)
with open("scripts/gameplay/departure_traffic_behavior.gd", "w") as f:
    f.write(content)
