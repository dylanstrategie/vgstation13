#define ABSORB_DEATH_GRACE_PERIOD 10 MINUTES
#define ABSORB_DELAY 50

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
	speed = 0.9 //TODO: Check speed compared to normal clothed human
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

	var/datum/role/changeling/changeling //Store our morph's changeling role for easy access

/mob/living/simple_animal/changeling_horror/New(var/loc)

	..(loc)

	morph = get_bottom_transmogrification()
	changeling = morph.mind.GetRole(CHANGELING)

/mob/living/simple_animal/changeling_horror/death(var/gibbed = FALSE)

	..(TRUE)

	//I wouldn't need to write this literally if simple animal didn't want to make hang myself jesus, why is passing "gib()" not enough ?
	visible_message("<span class='danger'>[src]'s entire structure bloats and explodes into viscera, revealing [morph]!",
	"<span class='danger'>Your greater form collapses outwards, leaving your lesser form suddenly exposed!</span></span>")
	monkeyizing = 1
	canmove = 0
	icon = null
	invisibility = 101
	dead_mob_list -= src

	anim(target = src, a_icon = 'icons/mob/animal.dmi', flick_anim = "c_horror_gib", sleeptime = 12) //Horror form gib is faster because I can't animate for shit, stichted it up
	sleep(6) //Sleep is 600 ms shorter for that effect, body appears once the THICC of the gib is gone
	gibs(loc, viruses, dna)
	qdel(src)

/mob/living/simple_animal/changeling_horror/Destroy()

	free_morph()
	..()

//Clean up the morph
/mob/living/simple_animal/changeling_horror/proc/free_morph()

	morph.Jitter(20) //Shake us up real good
	morph.Stun(5)
	morph.Knockdown(5)
	morph.bloody_body(morph, 1) //Greater form = time for a shower, even a clean demorph. Tab up to make on shock/collapse only

	completely_untransmogrify()

/mob/living/simple_animal/changeling_horror/ex_act(severity)

	if(flags & INVULNERABLE)
		return
	switch(severity)
		if(1)
			adjustBruteLoss(400) //Make ex_act 1 less of an instakill to prevent abuse

		if(2)
			adjustBruteLoss(60)


		if(3)
			adjustBruteLoss(30)

/mob/living/simple_animal/changeling_horror/Stat()
	..()
	if(statpanel("Status"))
		if(emergency_shuttle)
			if(emergency_shuttle.online && emergency_shuttle.location < 2)
				var/timeleft = emergency_shuttle.timeleft()
				if (timeleft)
					var/acronym = emergency_shuttle.location == 1 ? "ETD" : "ETA"
					stat(null, "[acronym]-[(timeleft / 60) % 60]:[add_zero(num2text(timeleft % 60), 2)]")

/mob/living/simple_animal/changeling_horror/UnarmedAttack(var/atom/A)

	if(busy) //We are busy doing -something-
		return

	if(istype(A, /obj/machinery/door)) //Forcing doors
		var/obj/machinery/door/D = A
		D.horror_force(src)

	//SUCC code below
	if(ishuman(A))
		var/mob/living/carbon/human/H = A
		if(can_absorb(H))
			//INSERT SUCC ATTACK CODE HERE
			//Classic do_after. Interrupting it will add extra attack_delay and NOT attack
			//You cannot attack ready to SUCC victims
			playsound(src, 'sound/effects/lingfullabsorb.ogg', 50, 1) //TODO: Make a custom mix for "succ + stabby"
			H.Paralyse(10) //SUCC will REALLY fuck you up, even if aborted. Yer getting stabbed right in the body mass buddy
			visible_message("<span class='danger'>[src] suddenly impales [H] with its claws and a proboscis and begins absorbing them!",
			"<span class='danger'>You impale [H] with your claws and a proboscis and begin absorbing them.</span></span>")
			busy = 1
			if(do_mob(src, H, ABSORB_DELAY))
				visible_message("<span class='danger'>[src] carefully removes his claws and proboscis from [H], goring them in the process!",
				"<span class='danger'>You carefully remove your claws and proboscis from [H], goring them in the process.</span></span>")
				apply_absorb_effects(H)

			else //We interrupted the succ
				visible_message("<span class='danger'>[src] suddenly removes his claws and proboscis from [H]!",
				"<span class='danger'>You remove your claws and proboscis from [H] as fast as possible.</span></span>")
				//Do not do "rip out" damage to prevent an ez pz kill finisher by cancelling it out repeatedly
			busy = 0

			delayNextAttack(20) //Changeling SUCC incurs a bigger delay, gotta unprong and all
			return

	return ..()

/mob/living/simple_animal/changeling_horror/proc/apply_absorb_effects(var/mob/living/carbon/human/H)

	H.apply_damage(rand(melee_damage_lower, melee_damage_upper), BRUTE)

	add_attacklogs(src, H, "changeling absorption/gore")

	//It makes the noise of a gib and leaves the mess of a gib, hence...
	var/gib_radius = 0
	if(H.reagents.has_reagent(LUBE)) //Can't possibly miss that piece of immersion here, can we ?
		gib_radius = 6 //Your insides are all lubed, so gibs travel much further
	hgibs(H.loc, H.viruses, H.dna, H.species.flesh_color, H.species.blood_color, gib_radius)

	//From there, we must know if the mob has genomes left or not
	//No genomes left = husk, DNA/language steal, death. Genomes left = Genome points only
	H.changeling_genomes_left-- //Take one muffin
	if(H.changeling_genomes_left)
		to_chat(src, "<span class='info'>You sense [H.changeling_genomes_left] genome feeds left inside of [H].</span>")
	else
		to_chat(src, "<span class='bnotice'>[H] has been fully drained of any useful genomes. We have their full, recomposed genetic structure for our uses. They are but a husk now.</span>")

		//Sanity on their DNA, then incorporate
		H.dna.real_name = H.real_name //Set this again, just to be sure that it's properly set.
		H.dna.flavor_text = H.flavor_text
		changeling.absorbed_dna |= H.dna

		//Steal all of their languages!
		for(var/language in H.languages)
			if(!(language in changeling.absorbed_languages))
				changeling.absorbed_languages += language

		changeling_update_languages(changeling.absorbed_languages)

		//Steal their species!
		if(H.species && !(H.species.name in changeling.absorbed_species))
			changeling.absorbed_species += H.species.name

		//Changelings absorbing other changelings, let nothing go to waste
		if(H.mind)
			var/datum/role/changeling/Tchangeling = H.mind.GetRole(CHANGELING)

			if(Tchangeling)
				if(Tchangeling.absorbed_dna)
					for(var/dna_data in Tchangeling.absorbed_dna) //Steal all their loot
						if(dna_data in changeling.absorbed_dna)
							continue
						changeling.absorbed_dna += dna_data
						changeling.absorbedcount++
						Tchangeling.absorbed_dna.Remove(dna_data)

				changeling.chem_charges += Tchangeling.chem_charges
				changeling.geneticpoints += Tchangeling.geneticpoints
				to_chat(src, "<span class='bnotice'>There is more to [H] than meets the eye. We have absorbed [Tchangeling.chem_charges] genome units and [Tchangeling.chem_charges] chemical charges. We are stronger, truly united.</span>")
				Tchangeling.chem_charges = 0
				Tchangeling.geneticpoints = 0
				//Tchangeling.absorbedcount = 0 //TODO: Check if this is a big deal

		//We recomposed all their DNA, so apply a MASSIVE genome boost (this pretty much doubles the bounty of 5 SUCCs from 50 to 100 genomes)
		changeling.chem_charges += 10
		changeling.geneticpoints += 50
		changeling.absorbedcount++

		//They die. RIP in pee pee
		H.death(0)
		H.Drain()

	/*
		Universal SUCC effects go there, like feeding/repenishing blood
	 */

	var/avail_blood = H.vessel.get_reagent_amount(BLOOD)
	for(var/datum/reagent/blood/B in morph.vessel.reagent_list)
		B.volume = min(BLOOD_VOLUME_MAX, avail_blood + B.volume)

	if(morph.nutrition < 400) //Dinner's ready
		morph.nutrition = min((morph.nutrition + H.nutrition), 400)

	//Effect for every succesful SUCC. "Full SUCC bonus" is above
	//TODO: Balance those values out. Smallest will be 1 DNA for a slash. 10 slashes = 1 SUCC phase. Bonus should double DNA output, so 50 rn
	changeling.chem_charges += 5
	changeling.geneticpoints += 10
	updateChangelingHUD()

//Do all the old checks that manual absorb did. Chat messages preserved for posteriority
/mob/living/simple_animal/changeling_horror/proc/can_absorb(var/mob/living/carbon/human/H)

	if(busy) //Never know
		return 0
	if(!istype(H)) //Failsafe, please pass correct arguments people!
		return 0
	if(M_NOCLONE in H.mutations || !H.changeling_genomes_left)
		//to_chat(src, "<span class='warning'>This creature's DNA is ruined beyond useability!</span>")
		return 0
	if(!H.mind)
		//to_chat(src, "<span class='warning'>This creature's DNA is useless to us!</span>")
		return 0
	if(!(H.stat == UNCONSCIOUS || (H.stat == DEAD && (H.tod < world.time - ABSORB_DEATH_GRACE_PERIOD))))
		//Mob is not unconscious, or has been dead for too long (5 mins grace at the time of this comment)
		return 0
	return 1
