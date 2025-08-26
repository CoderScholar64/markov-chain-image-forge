@icon("res://addons/scan_line_markov_image/icons/markov_chain_image_scanline_rules.svg")
class_name MarkovChainImageScanlineRules
extends Resource
## This resource stores rules in which an image can be generated from.
##
## The rules can be thought of as Markov Chain Rules. The algorithm works in a scan-line
## approach. An image is generated starting at the upper most pixel. It goes through
## the upper row and when done it goes to another row.[br]
## [br]
## [b]IMPORTANT:[/b] It is recommended to use this editor.
## [url=https://github.com/CoderScholar64/markov-chain-image-forge/]Markov Chain
## Image Forge[/url] as it allows you to make and edit these resources rather than
## manually using the code.[br]
## Simplified Usage:
## [codeblock]
## # The source_image is a 5x5 image with exactly two different colors. It is a plus symbol.
## var source_image := Image.create_from_data(5, 5, false, Image.Format.FORMAT_L8,
##         PackedByteArray([
##         0x00, 0x00, 0x00, 0x00, 0x00,
##         0x00, 0x00, 0xff, 0x00, 0x00,
##         0x00, 0xff, 0xff, 0xff, 0x00,
##         0x00, 0x00, 0xff, 0x00, 0x00,
##         0x00, 0x00, 0x00, 0x00, 0x00]) )
## var relative_position_checks: Array[Vector2i] = [
##     Vector2i(-1, -1),
##     Vector2i(-1,  0),
##     Vector2i( 0, -1),
## ]
## var checked_position_defaults: Array[int] = [0, 0, 0]
## var invalid_color := Color.FUCHSIA
##
## var ruleset := MarkovChainImageScanlineRules.create_rules(
##         source_image, relative_position_checks, checked_position_defaults, invalid_color)
##
## # WARNING: While all these parameters works. It is likely that create_rules would
## # not complete the ruleset with other parameters. This is why the editor is recommended.
##
## # Check if create_rules has failed
## if !ruleset:
##     # Error handling code
##     return
##
## if ruleset.get_known_state_factor() != 1.0:
##     # Warn the user that the generated image might have cases where a
##     # combination of pixels values is not present in the rule-set. If this
##     # occurs the generated image would stop at the cursor of where that
##     # error occurred.
##     pass
##
## # Check if rule-set has any errors.
## var potential_error_str := ruleset.get_error_string()
## if !potential_error_str.is_empty():
##     # Error handling code using potential_error_str
##     return
## 
## var generated_result: Dictionary[String, Variant]
## 
## if ruleset.does_color_format_work(Image.Format.FORMAT_RGBA8):
##    # If the unique colors would be distinct while quantified to 8 bits per channel
##    # then just use RGBA8.
##    generated_result = ruleset.generate_image(Vector2i(64,64))
## else:
##    # Otherwise the generated image would use 32 bit floating points per channel instead.
##    # In other words use the .exr color space. Overkill, but it makes the algorithm work.
##    generated_result = ruleset.generate_image(Vector2i(64,64), Image.Format.FORMAT_RGBAF)
## 
## if generated_result.has("problem"):
##     # Error handle what is in generated_result["problem"] it is a string.
##     pass
##
## if !generated_result.has("image"):
##     return # Cancel the operation.
## 
## var generated_image: Image = generated_result["image"]
## [/codeblock]
##
## @tutorial(How this Code Block Works): https://github.com/CoderScholar64/markov-chain-image-forge/blob/main/doc/plus_example.md
## @tutorial(Make this Resource via External Editor): https://coderscholar64.itch.io/markov-chain-image-forge


## This signal is called when the algorithm fails to complete the generated image.
## [param missing_rule] holds the rule that is the missing rule. [param image] is
## the image that is incomplete. The pixels that where not completed are in
## [member invalid_color]. [param coordinates] is the location where the image is
## not completed.[br][br]
## [method create_rules] emits this signal once if the image is not completed due
## to a missing rule while the repeat limit runs out. Otherwise, it will not emit
## this signal.
signal on_missing_rule(missing_rule: Array[int], image: Image, coordinates: Vector2i)


## This holds the positions relative to the cursor's position. The cursor is the
## current position of where the pixel is being chosen. If the read location is
## outside the images bounds then the pixel default is used. The default can be
## determined by [member checked_position_defaults][lb]same_index[rb].
##
## NOTE: This array's length should match the amount of checked positions that exists
## in these rules.
@export var cursor_positions: Array[Vector2i] = []

## This holds the defaults of the [member cursor_positions]. It holds the indexes
## to [member unique_colors] which holds the actual color values for the default
## colors.
##
## NOTE: This array's length should match the amount of checked positions that exists
## in these rules.
@export var checked_position_defaults: Array[int] = []

## This holds the colors that these rules produces. For its namesake make sure that
## each color stored in the array is different from each other. Make sure that also
## [member invalid_color] does not hold a color stored in this array.
##
## NOTE: This array's length should match the amount of colors that exists in these
## rules.
@export var unique_colors: Array[Color] = []

## This holds the color used to indicate if an image could not be completed either
## by missing rules and/or the repeat limit being reached.
##
## WARNING: This color should be distinct from [member unique_colors].
@export var invalid_color := Color.FUCHSIA

## This is used to store rules and probabilities. This dictionary holds the state
## as the key and probabilities as the value.[br]
## [br]
## NOTE: [Array]'s length should match the amount of checked positions that
## exists in these rules.[br]
## [br]
## NOTE: [PackedFloat32Array]'s length should match the amount of colors that
## exists in these rules.[br]
## [br]
## Example:
## [codeblock]
## var state: Array[int] = [0, 0, 0] # A state has many elements as cursor_positions.
## var possibilities: PackedFloat32Array = [0.2, 0.8] # Chances have many elements as unique_colors.
## ruleset.markov_matrix[state] = possibilities
## [/codeblock]
@export var markov_matrix: Dictionary[Array, PackedFloat32Array] = {}

## [b]ADVANCED USAGE:[/b] Check with the [method get_known_state_factor] if it is not 1.0 then
## it is very likely that [method generate_image] would cancel due to a missing rule.
## It is recommended to complete the model using the
## [url]https://github.com/CoderScholar64/markov-chain-image-forge/[/url].[br]
## This static method is to declare a new [MarkovChainImageScalineRules]. Return
## a null if [param cursor_positions] is empty or the lengths of [param cursor_positions]
## and [param checked_position_defaults] do not match. Returns either an valid or
## [u][b]invalid[/b][/u] [MarkovChainImageScalineRules] otherwise. First check if
## with [method get_error_string] and then [method does_color_format_work] to see
## if the rules works.[br]
##
## [param source_image] the seed in which the rules are created.[br]
## [param invalid_color] is member [member invalid_color]. It should be a color not
## present on the image.[br]
## [param cursor_positions] is member [member cursor_positions]. It should be set to
## relative positions coming before the cursors.[br]
## [param checked_position_defaults] is member [member checked_position_defaults].
## These values are used when the position read from the cursor is out of bounds.[br]
## [br]
static func create_rules(source_image: Image,
		cursor_positions: Array[Vector2i], checked_position_defaults: Array[int],
		invalid_color := Color.FUCHSIA ) -> MarkovChainImageScanlineRules:
	if cursor_positions.is_empty() or len(cursor_positions) != len(checked_position_defaults):
		return null
	
	var new_rules := MarkovChainImageScanlineRules.new()
	new_rules.cursor_positions = cursor_positions
	new_rules.checked_position_defaults = checked_position_defaults
	new_rules.invalid_color = invalid_color
	
	new_rules.unique_colors = extract_unique_colors(source_image)
	
	var pixel_index_neighbors: Array[int] = []
	var pixel_index: int = 0
	
	for x in checked_position_defaults:
		pixel_index_neighbors.append(0)
	
	for y in source_image.get_size().y:
		for x in source_image.get_size().x:
			
			for i in len(pixel_index_neighbors):
				if 		(x + new_rules.cursor_positions[i].x) >= source_image.get_size().x or\
						(y + new_rules.cursor_positions[i].y) >= source_image.get_size().y or\
						(x + new_rules.cursor_positions[i].x) < 0 or\
						(y + new_rules.cursor_positions[i].y) < 0:
					pixel_index_neighbors[i] = new_rules.checked_position_defaults[i]
				else:
					var new_position := Vector2i(x, y) + new_rules.cursor_positions[i]
					var pixel_value  := source_image.get_pixelv(new_position)
					
					pixel_index_neighbors[i] = new_rules.unique_colors.find(pixel_value)
			
			pixel_index = new_rules.unique_colors.find(source_image.get_pixel(x, y))
			
			if !new_rules.markov_matrix.has(pixel_index_neighbors):
				new_rules.markov_matrix[pixel_index_neighbors.duplicate()] = PackedFloat32Array()
				
				for u in new_rules.unique_colors:
					new_rules.markov_matrix[pixel_index_neighbors].append( 0.0 )
			
			if pixel_index >= 0:
				new_rules.markov_matrix[pixel_index_neighbors][pixel_index] += 1.0
	
	for markov_link in new_rules.markov_matrix:
		var sum: float = 0.0
		
		for pixel in len(new_rules.markov_matrix[markov_link]):
			sum += new_rules.markov_matrix[markov_link][pixel]
			
		var inv_sum: float = 1.0 / sum
		
		for pixel in len(new_rules.markov_matrix[markov_link]):
			new_rules.markov_matrix[markov_link][pixel] *= inv_sum
	
	return new_rules

## This static function returns unique_colors from an image.
## Data complexity O([b]n[/b]) with [b]n[/b] being the [b]n[/b]umber or pixels.
## [b]n[/b] equals [color=33ff33]width[/color] * [color=ff3333]height[/color].
static func extract_unique_colors(source_image: Image) -> Array[Color]:
	var unique_colors: Array[Color] = []
	
	for y in source_image.get_size().y:
		for x in source_image.get_size().x:
			var pixel := source_image.get_pixel(x, y)
			
			if !unique_colors.has(pixel):
				unique_colors.append(pixel)
	
	return unique_colors

## This method attempts to generate an image derived from rules and randomness.[br]
## [param image_size] a [Vector2i] holding the size of the image that is to be generated.
## Of course make sure that both x and y are greater than zero. Also make sure that
## they do not exceed [constant Image.MAX_WIDTH] and [constant Image.MAX_HEIGHT].[br]
## [param image_format] specifies the kind of [enum Image.Format] that the image 
## data would be encoded. [code]Image.Format.FORMAT_RGBA8[/code] is the default value.[br]
## [param repeat_limit] this parameter is for advanced usage. It is the number of
## times that one or more scan lines can be discarded. This condition only occurs
## if no rule is found for a pixel combination. Thus, if your rule-set is complete
## then this parameter does nothing useful.[br]
## [param random_number_gen] This is the specific [RandomNumberGenerator] used to
## generate this image. This is useful for generating deterministic images.[br]
## Returns a dictionary holding these values.[br]
## [b]status[/b]: If -1 then image was not allocated at all. This could
## happen if the [param image_format] [method does_color_format_work] returns
## [code]false[/code]. If 0 then the image was not completed due to a missing
## rule. If 1 then the image is complete.[br]
## [b]problem[/b]: If status is not 1, then this will be present with a [String][br]
## [b]cursor[/b]: Present if there is a missing rule encountered.[br]
## [b]image[/b]: If status is not -1, then this will be present with an [Image]
## holding either a completed output or an incomplete output.[br]
func generate_image(
		image_size: Vector2i,
		image_format := Image.Format.FORMAT_RGBA8,
		repeat_limit: int = 0,
		random_number_gen: RandomNumberGenerator = null) -> Dictionary[String, Variant]:
	
	if !does_color_format_work(image_format):
		return {
			"status": -1,
			"problem": "image format is not compatible with these rules"
		}
	
	if random_number_gen == null:
		random_number_gen = RandomNumberGenerator.new()
		random_number_gen.randomize()
	
	var image := Image.create_empty(image_size.x, image_size.y, false, image_format)
	
	if !image:
		return {
			"status": -1,
			"problem": "image failed to allocate!"
		}
	
	var pixel_position := Vector2i(0, 0)
	
	var pixel_neighbors: Array[int] = []
	
	pixel_neighbors.resize(len(cursor_positions))
		
	if repeat_limit == 0:
		pixel_position = _generate_image_attempt(
			image, pixel_position, random_number_gen, pixel_neighbors)
	else:
		var limiter := repeat_limit
		
		var last_halt_point := Vector2i(-1, -1)
		var go_back: int = 1
		
		while limiter >= 0:
			if pixel_position == image_size:
				break
			
			limiter -= 1
			
			if last_halt_point != pixel_position:
				go_back =  1
			else:
				go_back += 1
			
			pixel_position.y = maxi(pixel_position.y - go_back, 0)
			
			last_halt_point = pixel_position
			
			pixel_position = _generate_image_attempt(
				image, pixel_position, random_number_gen, pixel_neighbors)
	
	if pixel_position != image_size:
		on_missing_rule.emit(pixel_neighbors, image, pixel_position)
		
		var temp_x: int = pixel_position.x
		var temp_y: int = pixel_position.y
		
		for y in range(temp_y, image.get_size().y):
			temp_y = 0
			
			for x in range(temp_x, image.get_size().x):
				temp_x = 0
				
				image.set_pixel(x, y, invalid_color)
		return {
			"image": image,
			"cursor": pixel_position,
			"status": 0,
			"problem": "A rule needed to complete the image is not found!",
		}
	else:
		return {"image": image, "status": 1}


func _generate_image_attempt(
		image: Image,
		starting_position: Vector2i,
		random_number_gen: RandomNumberGenerator,
		pixel_neighbors: Array[int]) -> Vector2i:
	var computed_position    := Vector2i()
	var selected_color_index := 0
	
	var temp_x: int = starting_position.x
	var temp_y: int = starting_position.y
	var read_color := Color()
	
	for y in range(temp_y, image.get_size().y):
		temp_y = 0
		
		for x in range(temp_x, image.get_size().x):
			temp_x = 0
			
			for index in len(cursor_positions):
				computed_position = Vector2i(x, y) + cursor_positions[index]
				
				if (
					0 > computed_position.x or 0 > computed_position.y or
					image.get_size().x <= computed_position.x or
					image.get_size().y <= computed_position.y
				):
					selected_color_index = checked_position_defaults[index]
				else:
					read_color = image.get_pixelv(computed_position)
					selected_color_index = unique_colors.find(read_color)
				
				pixel_neighbors[index] = selected_color_index
			
			if !markov_matrix.has(pixel_neighbors):
				image.set_pixel(x, y, invalid_color)
				
				return Vector2i( x, y )
			else:
				var existing_state := markov_matrix[pixel_neighbors]
				var choosen_index  := random_number_gen.rand_weighted(existing_state)
				var choosen_color  := unique_colors[choosen_index]
				
				image.set_pixel(x, y, choosen_color)
	
	return image.get_size()

## This method checks to see if the colors stays unique if the colors get quantified.
## The reason for uniqueness is because the algorithm used to generate the image
## would not work.[br]
## This method returns [code]true[/code] if the colors on a generated image would
## be unique.
func does_color_format_work(image_format := Image.Format.FORMAT_RGBAF) -> bool:
	if image_format == Image.Format.FORMAT_RGBAF:
		return _are_colors_unique()
	
	# TODO This is a workaround due to the lack of static color conversion options
	# on the Image class.
	var image := Image.create_empty(1, 1, false, image_format)
	
	assert(image, "does_color_format_work fails because image failed to allocate!")
	
	if !image:
		return false
	
	var uniqueness: Dictionary[Color, int] = {}
	
	image.set_pixel(0, 0, invalid_color)
	uniqueness[image.get_pixel(0, 0)] = 0
	
	for raw_color in unique_colors:
		image.set_pixel(0, 0, raw_color)
		var color := image.get_pixel(0, 0)
		
		if uniqueness.has(color):
			return false
		
		uniqueness[color] = 0
	
	return true


func _are_colors_unique() -> bool:
	var uniqueness: Dictionary[Color, int] = {}
	
	uniqueness[invalid_color] = 0
	
	for color in unique_colors:
		if uniqueness.has(color):
			return false
		
		uniqueness[color] = 0
	
	return true

## Return the number of elements held in [member markov_matrix].
func get_num_states() -> int:
	return len(markov_matrix)

## Return the max of the elements that can be stored given the [member unique_colors]
## and [member check_position_defaults]
func get_max_states() -> int:
	return len(unique_colors) ** len(checked_position_defaults)

## Return 1.0 if all the states are present in [member markov_matrix]. Returns 0.0
## if there is no single state in this resource. In between, is how much this resource's
## states are known. The closer to 1.0 the more the states are known.
func get_known_state_factor() -> float:
	return float(get_num_states()) / float(get_max_states())

## This method is designed to tell the programmer if there is anything wrong with
## this resource. If this resource returns an [b]empty[/b] [String] then this resource
## can generate an image without crashing. If not then read from the text returned
## by this method.
func get_error_string() -> String:
	if cursor_positions.is_empty():
		return "cursor_positions is empty"
	
	if len(cursor_positions) != len(checked_position_defaults):
		return "cursor_positions length is {L} while checked_position_defaults is {D}.".format(
			{"L": len(cursor_positions), "D": len(checked_position_defaults)}
		)
	
	for index in len(cursor_positions):
		var cursor_relative := cursor_positions[index]
		
		if cursor_relative.y > 0:
			return "cursor_positions[{I}] or {V} is bellow the point where the pixels "+\
				"are written.\nIf y is 0 then x should be bellow zero. If y is "+\
				"negative then x can be any value.".format({"I": index, "V": cursor_relative})
		elif cursor_relative.y == 0:
			if cursor_relative.x >= 0:
				return "cursor_positions[{I}] or {V} is bellow the point where the pixels "+\
					"are written.\nIf y is 0 then x should be bellow zero. If y is "+\
					"negative then x can be any value.".format({"I": index, "V": cursor_relative})
	
	if len(unique_colors) < 2:
		return "You need at least two unique colors to generate an image."
	
	if !_are_colors_unique():
		return "Each individual color from unique_colors and invalid_color must " +\
			"be different!"
	
	for state in markov_matrix:
		if state is not Array[int]:
			return 'State "{R}" should be exactly Array[int]'.format({"R": state})
		
		if len(state) != len(cursor_positions):
			return 'State "{R}" should be length of {L} not {RL}'.format(
				{"R": state, "L": len(cursor_positions), "RL": len(state)}
			)
		
		if markov_matrix[state] is not PackedFloat32Array:
			return 'State "{R}" should have a PackedFloat32Array'.format({"R": state})
		
		if len(markov_matrix[state]) != len(unique_colors):
			return 'Probabilities of state "{R}" should be length of {L} not {RL}'.format(
				{"R": state, "L": len(unique_colors), "RL": len(markov_matrix[state])}
			)
	
	return "" # Empty string for success
