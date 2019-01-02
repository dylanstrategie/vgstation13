/*

/datum/species/horror // /vg/
	name = "Horror"
	icobase = 'icons/mob/human_races/r_horror.dmi'
	deform = 'icons/mob/human_races/r_horror.dmi'  // TODO: Need deform.
	known_languages = list(LANGUAGE_CLATTER)
	attack_verb = "smashes"
	flags = NO_BREATHE /*| NON_GENDERED*/ | NO_PAIN | HYPOTHERMIA_IMMUNE
	anatomy_flags = HAS_SWEAT_GLANDS | NO_BLOOD
	pressure_resistance = 30 * ONE_ATMOSPHERE /*No longer will our ascent be foiled by depressurization!*/
	//h_style = null

	// Yep.
	default_mutations=list(M_HULK)

	cold_level_1 = 0 //Default 220 - Lower is better
	cold_level_2 = 10 //Default 200
	cold_level_3 = 20 //Default 120

	heat_level_1 = 420 //Default 360 - Higher is better
	heat_level_2 = 480 //Default 400
	heat_level_3 = 1100 //Default 1000


	warning_low_pressure = 50
	hazard_low_pressure = 0

	max_hurt_damage = 30 /*It costs 30 points, it should crit in 3 hits.*/

	// Same as disposal
	punch_throw_speed = 1
	punch_throw_range = 10

	throw_mult = 1.5 // +0.5 for hulk
	fireloss_mult = 2 // double the damage, half the fun

	override_icon = 'icons/mob/horror.dmi'
	has_mutant_race = 0

/datum/species/horror/handle_post_spawn(var/mob/living/carbon/human/H)
	H.h_style = "Bald"
	H.f_style = "Shaved"
	H.update_hair()

*/

/mob/living/simple_animal/changeling_horror
	name = "changeling horror"
	real_name = "changeling horror"
	desc = "A disgusting mess of pulsating flesh and displaced organs, shaped like a human that grotesquely bursted apart"
	speak_emote = list("screeches")
	emote_hear = list("screeches")
	response_help  = "hugs the"
	response_disarm = "pushes the"
	response_harm   = "punches the"
	icon_state = "c_horror"
	icon_living = "c_horror"
	icon_dead = "c_horror_dead"
	speed = 1 //TODO: Check speed compared to normal clothed human
	size = SIZE_BIG //He's a large boy
	a_intent = I_HURT
	attacktext = "shreds"
	friendly = "hugs"
	maxHealth = 800
	health = 800
	minbodytemp = 0
	maxbodytemp = 4000
	min_oxy = 0
	max_co2 = 0
	max_tox = 0
	melee_damage_lower = 25
	melee_damage_upper = 35
	environment_smash_flags = SMASH_LIGHT_STRUCTURES | SMASH_CONTAINERS

	//Player controlled, no AI shit
	stop_automated_movement = 1
	wander = 0

	//Changeling holder. This is where the human we are carrying goes
	var/mob/living/carbon/human/morph

	var/busy = 0 //Used for interactions like door forcing

/mob/living/simple_animal/changeling_horror/New(var/loc, var/mob/living/carbon/human/H)

	..(loc)
	H.forceMove(src)
	morph = H

/mob/living/simple_animal/changeling_horror/Destroy()

	monkeyizing = 1
	canmove = 0
	delayNextAttack(50)
	invisibility = 101
	alpha = 0 //Oh lord, there has to be a better way

	var/atom/movable/overlay/animation = new /atom/movable/overlay( loc )

	animation.icon_state = "blank"
	animation.icon = 'icons/mob/mob.dmi'
	animation.master = src
	flick("h2horror_r", animation)
	sleep(14) // Frames
	qdel(animation)

	if(morph)
		morph.forceMove(loc)
		morph.timestopped = 0
		if(mind)
			mind.transfer_to(morph)
		else
			morph.key = key
		emote("quietly whimpers as its entire structure collapses, revealing [morph]!")
		morph = null
	..()

/mob/living/simple_animal/changeling_horror/death()

	if(morph)
		morph.forceMove(loc)
		morph.timestopped = 0
		if(mind)
			mind.transfer_to(morph)
		else
			morph.key = key
		emote("lets out a blood curling screech as its entire structure bloats and explodes into viscera, revealing [morph]!")
		morph = null

	gib()

	..()

//Sanity
/mob/living/simple_animal/changeling_horror/gib()

	if(morph)
		morph.forceMove(loc)
		morph.timestopped = 0
		if(mind)
			mind.transfer_to(morph)
		else
			morph.key = key
		emote("lets out a blood curling screech as its entire structure bloats and explodes into viscera, revealing [morph]!")
		morph = null

	..()

/mob/living/simple_animal/changeling_horror/Stat()
	..()
	if(statpanel("Status"))
		if(emergency_shuttle)
			if(emergency_shuttle.online && emergency_shuttle.location < 2)
				var/timeleft = emergency_shuttle.timeleft()
				if (timeleft)
					var/acronym = emergency_shuttle.location == 1 ? "ETD" : "ETA"
					stat(null, "[acronym]-[(timeleft / 60) % 60]:[add_zero(num2text(timeleft % 60), 2)]")

		stat("Health", health)

/mob/living/simple_animal/changeling_horror/UnarmedAttack(var/atom/A)

	if(busy) //We are busy doing -something-
		return

	if(istype(A, /obj/machinery/door)) //Forcing doors
		var/obj/machinery/door/D = A
		D.horror_force(src)

	return ..()
