/mob/proc/updateChangelingHUD()
	if(hud_used)
		var/datum/role/changeling/changeling = mind.GetRole(CHANGELING)
		if(!changeling)
			return
		if(!hud_used.vampire_blood_display)
			hud_used.changeling_hud()
			//hud_used.human_hud(hud_used.ui_style)
		hud_used.vampire_blood_display.maptext_width = WORLD_ICON_SIZE*2
		hud_used.vampire_blood_display.maptext_height = WORLD_ICON_SIZE
		var/C = round(changeling.chem_charges)
		hud_used.vampire_blood_display.maptext = "<div align='left' valign='top' style='position:relative; top:0px; left:6px'>\
				C:<font color='#EAB67B'>[C]</font><br>\
				G:<font color='#FF2828'>[changeling.absorbedcount]</font><br>\
				[changeling.geneticdamage ? "GD: <font color='#8b0000'>[changeling.geneticdamage]</font>" : ""]\
				</div>"

//Used to dump the languages from the changeling datum into the actual mob.
/mob/proc/changeling_update_languages(var/updated_languages)

	languages.len = 0
	for(var/language in updated_languages)
		languages += language

	//This isn't strictly necessary but just to be safe...
	add_language("Changeling")

/obj/item/verbs/changeling/proc/changeling_change_species()
	set category = "Changeling"
	set name = "Change Species (5)"

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_change_species()

//Used to switch species based on the changeling datum.
/mob/proc/changeling_change_species()
	var/mob/living/carbon/human/H = src
	if(!istype(H))
		to_chat(src, "<span class='warning'>We may only use this power while in humanoid form.</span>")
		return

	var/datum/role/changeling/changeling = changeling_power(5, 1, 0)
	if(!changeling)
		return

	if(changeling.absorbed_species.len < 2)
		to_chat(src, "<span class='warning'>We do not know of any other species genomes to use.</span>")
		return

	var/S = input("Select the target species: ", "Target Species", null) as null|anything in changeling.absorbed_species
	if(!S)
		return

	domutcheck(src, null)

	changeling.chem_charges -= 5
	changeling.geneticdamage = 30

	src.visible_message("<span class='warning'>[src] transforms!</span>")

	src.verbs -= /mob/proc/changeling_change_species
	H.set_species(S,1) //Until someone moves body colour into DNA, they're going to have to use the default.

	spawn(10)
		src.verbs += /mob/proc/changeling_change_species
		src.regenerate_icons()

	changeling_update_languages(changeling.absorbed_languages)
	feedback_add_details("changeling_powers","TR")

	return 1

/spell/horror_form
	name = "Horror Form"
	desc = "We become greater. We are incredibly strong, to the point that we can force open airlocks and are immune to conventional stuns, but this form is unstable yet."
	abbreviation = "HF"

	school = "changeling"
	user_type = USER_TYPE_CHANGELING

	charge_type = Sp_RECHARGE
	charge_max = 2 MINUTES
	cooldown_min = 2 MINUTES
	range = 0
	spell_flags = STATALLOWED | NEEDSHUMAN
	invocation = ""
	invocation_type = SpI_NONE

	override_base = "genetic" //For now, I guess
	hud_state = "ling_horror"

	var/chemical_cost = 30

/spell/horror_form/cast_check(var/skipcharge = 0, var/mob/user = usr)
	. = ..()
	if (!.) // No need to go further.
		return FALSE
	if(!user.changeling_power(chemical_cost, 0, 0))
		return FALSE

/spell/horror_form/choose_targets(var/mob/user = usr)
	return list(user) // Self-cast

/spell/horror_form/cast(var/list/targets, var/mob/user)
	if(!user.client)
		return FALSE

	user.monkeyizing = 1
	user.canmove = 0
	user.delayNextAttack(50)
	user.invisibility = 101
	user.alpha = 0 //Oh lord, there has to be a better way

	user.visible_message("<span class='danger'>[user] emits a putrid odor as their torso splits open!</span>")
	playsound(user.loc, 'sound/effects/gib1.ogg', 50, 0)
	anim(target = user, a_icon = 'icons/mob/mob.dmi', flick_anim = "h2horror", sleeptime = 14)
	sleep(14) // Frames

	user.transmogrify(/mob/living/simple_animal/changeling_horror, /spell/horror_form_revert)

	user.monkeyizing = 0
	user.canmove = 1
	user.delayNextAttack(0)
	user.invisibility = initial(user.invisibility)
	user.alpha = initial(user.alpha)

/spell/horror_form_revert
	name = "Normal Form"
	desc = "We return to our normal form. We will be knocked out for a bit."
	abbreviation = "NF"

	school = "changeling"
	user_type = USER_TYPE_CHANGELING

	charge_max = 1
	range = 0
	invocation = ""
	invocation_type = SpI_NONE
	spell_flags = STATALLOWED

	override_base = "genetic" //For now, I guess
	hud_state = "ling_normal"

/spell/horror_form/choose_targets(var/mob/user = usr)
	return list(user) // Self-cast

/spell/horror_form_revert/cast(var/list/targets, mob/user)
	user.visible_message("<span class='danger'>[user]'s structure breaks back down into a humanoid shape, revealing [user.get_top_transmogrification()]!",
	"<span class='danger'>Your greater form carefully breaks and bends, returning you to your weaker form.</span></span>")
	user.monkeyizing = 1
	user.canmove = 0
	user.icon = null
	user.delayNextAttack(50)
	user.invisibility = 101
	anim(target = user, a_icon = 'icons/mob/mob.dmi', flick_anim = "h2horror_r", sleeptime = 14)
	sleep(14) //So yeah, you still need that sleep afterwards, go figure

	user.transmogrify()
	user.Knockdown(2) //Need a second to get your senses back
	user.Jitter(5) //Shake us up real good
	user.remove_spell(src)

//Helper proc. Does all the checks and stuff for us to avoid copypasta
/mob/proc/changeling_power(var/required_chems = 0, var/required_dna = 0, var/max_genetic_damage = 100, var/max_stat = 0)

	if(timestopped)
		return 0 //under effects of time magick

	if(!mind)
		return 0

	var/datum/role/changeling/changeling = mind.GetRole(CHANGELING)
	if(!changeling)
		world.log << "[src] has the changeling_transform() verb but is not a changeling."
		return 0

	if(stat > max_stat)
		to_chat(src, "<span class='warning'>We are incapacitated.</span>")
		return 0

	if(changeling.absorbed_dna.len < required_dna)
		to_chat(src, "<span class='warning'>We require at least [required_dna] samples of compatible DNA.</span>")
		return 0

	if(changeling.chem_charges < required_chems)
		to_chat(src, "<span class='warning'>We require at least [required_chems] units of chemicals to do that!</span>")
		return 0

	if(changeling.geneticdamage > max_genetic_damage)
		to_chat(src, "<span class='warning'>Our genomes are still reassembling. We need time to recover first.</span>")
		return 0

	return 1

/spell/changeling_transform
	name = "Change Appearance (5)"
	desc = "We take on the appearance and voice of one we have absorbed."
	abbreviation = "CA"

	school = "changeling"
	user_type = USER_TYPE_CHANGELING

	charge_type = Sp_RECHARGE
	charge_max = 30 SECONDS
	invocation_type = SpI_NONE
	range = 0
	spell_flags = STATALLOWED | NEEDSHUMAN
	cooldown_min = 30 SECONDS

	override_base = "genetic" //For now, I guess
	hud_state = "ling_transform"

	var/chemical_cost = 5

/spell/changeling_transform/cast_check(var/skipcharge = 0, var/mob/user = usr)
	. = ..()
	if (!.) // No need to go further.
		return FALSE
	if(!user.changeling_power(chemical_cost, 1, 0))
		return FALSE

/spell/changeling_transform/choose_targets(var/mob/user = usr)
	return list(user) // Self-cast

/spell/changeling_transform/cast(var/list/targets, var/mob/user)
	if(!user.client)
		return FALSE

	var/datum/role/changeling/changeling = user.mind.GetRole(CHANGELING)

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)
		return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	user.visible_message("<span class='warning'>[user] transforms!</span>",
	"<span class='notice'>You transform your identity.</span>")
	var/oldspecies = user.dna.species
	user.dna = chosen_dna.Clone()
	user.real_name = chosen_dna.real_name
	user.flavor_text = chosen_dna.flavor_text
	user.UpdateAppearance()
	var/mob/living/carbon/human/H = user
	if(istype(H) && oldspecies != user.dna.species)
		H.set_species(H.dna.species, 0)
	domutcheck(user, null)

	changeling.chem_charges -= 5
	changeling.geneticdamage = 30

/*
/obj/item/verbs/changeling/proc/changeling_lesser_form()
	set category = "Changeling"
	set name = "Lesser Form (1)"

	var/mob/M = loc
	if(!istype(M))
		return

	if(!M.changeling_can_lesser_form())
		to_chat(M, "<span class='warning'>We cannot perform this ability in this location!</span>")
		return
	if(ishuman(M))
		M.changeling_lesser_form()
	else if(ismonkey(M))
		M.changeling_lesser_transform()
	else
		to_chat(M, "<span class='warning'>We cannot perform this ability in this form!</span>")

/mob/proc/changeling_can_lesser_form()
	if(istype(loc, /obj/mecha))
		return FALSE
	if(istype(loc, /obj/machinery/atmospherics))
		return FALSE
	return TRUE

//Transform into a monkey. 	//TODO replace with monkeyize proc
/mob/proc/changeling_lesser_form()
	var/datum/role/changeling/changeling = changeling_power(1, 0, 0)
	if(!changeling)
		return

	var/mob/living/carbon/human/C = src

	if(!istype(C) || !C.species.primitive)
		to_chat(src, "<span class='warning'>We cannot perform this ability in this form!</span>")
		return

	if(M_HUSK in C.mutations)
		to_chat(C, "<span class = 'warning'>This hosts genetic code is too scrambled. We can not change form until we have removed this burden.</span>")
		return

	changeling.chem_charges--
	C.remove_changeling_powers()
	C.visible_message("<span class='warning'>[C] transforms!</span>")
	changeling.geneticdamage = 30
	to_chat(C, "<span class='warning'>Our genes cry out!</span>")
	C.remove_changeling_verb() //remove the verb holder
	var/mob/living/carbon/monkey/O = C.monkeyize(ignore_primitive = 1) // stops us from becoming the monkey version of whoever we were pretending to be
	O.make_changeling(1)
	var/datum/role/changeling/Ochangeling = O.mind.GetRole(CHANGELING)
	O.changeling_update_languages(Ochangeling.absorbed_languages)
	feedback_add_details("changeling_powers","LF")
	C = null
	return 1

//Transform into a human
/mob/proc/changeling_lesser_transform()
	var/datum/role/changeling/changeling = changeling_power(1,1,0)
	if(!changeling)
		return

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)
		return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	var/mob/living/carbon/C = src

	changeling.chem_charges--
	C.remove_changeling_powers()
	C.visible_message("<span class='warning'>[C] transforms!</span>")
	C.dna = chosen_dna.Clone()

	C.monkeyizing = 1
	C.canmove = 0
	C.icon = null
	C.overlays.len = 0
	C.invisibility = 101
	C.delayNextAttack(50)
	var/atom/movable/overlay/animation = new /atom/movable/overlay( C.loc )
	animation.icon_state = "blank"
	animation.icon = 'icons/mob/mob.dmi'
	animation.master = src
	flick("monkey2h", animation)
	sleep(48)
	qdel(animation)
	animation = null

	var/mob/living/carbon/human/O = new /mob/living/carbon/human( src, delay_ready_dna=1 )
	if (C.dna.GetUIState(DNA_UI_GENDER))
		O.setGender(FEMALE)
	else
		O.setGender(MALE)
	C.transferImplantsTo(O)
	C.transferBorers(O)
	O.dna = C.dna.Clone()
	C.dna = null
	O.real_name = chosen_dna.real_name
	O.flavor_text = chosen_dna.flavor_text
	C.remove_changeling_verb()

	for(var/obj/item/W in src)
		C.drop_from_inventory(W)
	for(var/obj/T in C)
		qdel(T)

	O.forceMove(C.loc)

	O.UpdateAppearance()
	domutcheck(O, null)
	O.setToxLoss(C.getToxLoss())
	O.adjustBruteLoss(C.getBruteLoss())
	O.setOxyLoss(C.getOxyLoss())
	O.adjustFireLoss(C.getFireLoss())
	O.stat = C.stat
	O.delayNextAttack(0)
	C.mind.transfer_to(O)
	O.make_changeling()
	O.changeling_update_languages(changeling.absorbed_languages)

	feedback_add_details("changeling_powers","LFT")
	qdel(C)
	C = null
	return 1


//Fake our own death and fully heal. You will appear to be dead but regenerate fully after a short delay.
/mob/verb/check_mob_list()
	set name = "(Mobs) Check Mob List"
	set hidden = 1
	var/yes = 0
	if(src in mob_list)
		yes = 1
	else
		var/mob/M = locate(src) in mob_list
		if(M == src)
			yes = 1
	to_chat(usr, "[yes ? "<span class='good'>" : "<span class='bad'>"] You are [yes ? "" : "not "]in the mob list</span>")
	yes = 0
	if(src in living_mob_list)
		yes = 1
	else
		var/mob/M = locate(src) in living_mob_list
		if(M == src)
			yes = 1
	to_chat(usr, "[yes ? "<span class='good'>" : "<span class='bad'>"] You are [yes ? "" : "not "]in the living mob list</span>")

/obj/item/verbs/changeling/proc/changeling_returntolife()
	set category = "Changeling"
	set name = "Return To Life (20)"

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_returntolife()

/mob/proc/changeling_returntolife()
	var/datum/role/changeling/changeling = changeling_power(20,1,100,DEAD)
	if(!changeling)
		return
	var/mob/living/carbon/C = src
	if(changeling_power(20,1,100,DEAD))
		changeling.chem_charges -= 20
		dead_mob_list -= C
		living_mob_list |= list(C)
		C.stat = CONSCIOUS
		C.tod = null
		C.revive(0)
		to_chat(C, "<span class='notice'>We have regenerated.</span>")
		C.visible_message("<span class='warning'>[src] appears to wake from the dead, having healed all wounds.</span>")
		C.status_flags &= ~(FAKEDEATH)
		C.update_canmove()
		C.make_changeling()
		if(M_HUSK in mutations) //Yes you can regenerate from being husked if you played dead beforehand, but unless you find a new body, you can not regenerate again.
			to_chat(C, "<span class='notice'>This host body has become corrupted, either through a mishap, or betrayal by a member of the hivemind. We must find a new form, lest we lose ourselves to the void and become dust.</span>")
			if(dna in changeling.absorbed_dna)
				changeling.absorbed_dna.Remove(dna)
	regenerate_icons()
	remove_changeling_verb(/obj/item/verbs/changeling/proc/changeling_returntolife)
	feedback_add_details("changeling_powers","RJ")

/obj/item/verbs/changeling/proc/changeling_fakedeath()
	set category = "Changeling"
	set name = "Regenerative Stasis (20)"

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_fakedeath()

/mob/proc/changeling_fakedeath()
	/*
	// BYOND bug where verbs don't update if you're not on a turf, as such you'll be permanently stuck in regen statis until you get moved to a turf.
	if(!isturf(loc))
		to_chat(src, "<span class='warning'>((Due to a BYOND bug, it is not possible to come out of regenerative statis if you are not on a turf (walls, floors...)))</span>")
		return
	*/ //Fixed with the introduction of the changeling verb holder

	var/datum/role/changeling/changeling = changeling_power(20,1,100,DEAD)
	if(!changeling)
		return

	var/mob/living/carbon/C = src
	if(C.suiciding)
		to_chat(C, "<span class='warning'>Why would we wish to regenerate if we have already committed suicide?")
		return

	if(M_HUSK in C.mutations)
		to_chat(C, "<span class='warning'>We can not regenerate from this. There is not enough left to regenerate.</span>")
		return

	if(!C.stat && alert("Are we sure we wish to fake our death?",,"Yes","No") == "No")//Confirmation for living changelings if they want to fake their death
		return
	to_chat(C, "<span class='notice'>We will attempt to regenerate our form.</span>")

	C.status_flags |= FAKEDEATH		//play dead
	C.update_canmove()
	C.remove_changeling_powers()

	C.emote("deathgasp")
	C.tod = worldtime2text()
	var/time_to_take = rand(800, 1200)
	to_chat(C, "<span class='notice'>This will take [round((time_to_take/10))] seconds.</span>")
	spawn(time_to_take)
		to_chat(src, "<span class='warning'>We are now ready to regenerate.</span>")
		add_changeling_verb(/obj/item/verbs/changeling/proc/changeling_returntolife)

	feedback_add_details("changeling_powers","FD")
	return 1

/obj/item/verbs/changeling/proc/changeling_boost_range()
	set category = "Changeling"
	set name = "Ranged Sting (10)"
	set desc = "Your next sting ability can be used against targets 2 squares away."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_boost_range()

//Boosts the range of your next sting attack by 1
/mob/proc/changeling_boost_range()
	var/datum/role/changeling/changeling = changeling_power(10,0,100)
	if(!changeling)
		return 0
	changeling.chem_charges -= 10
	to_chat(src, "<span class='notice'>Your throat adjusts to launch the sting.</span>")
	changeling.sting_range = 2

	remove_changeling_verb(/obj/item/verbs/changeling/proc/changeling_boost_range)
	spawn(5)
		add_changeling_verb(/obj/item/verbs/changeling/proc/changeling_boost_range)

	feedback_add_details("changeling_powers","RS")
	return 1

/obj/item/verbs/changeling/proc/changeling_unstun()
	set category = "Changeling"
	set name = "Epinephrine Sacs (45)"
	set desc = "Removes all stuns."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_unstun()

//Recover from stuns.
/mob/proc/changeling_unstun()
	var/datum/role/changeling/changeling = changeling_power(45,0,100,UNCONSCIOUS)
	if(!changeling)
		return 0
	changeling.chem_charges -= 45

	var/mob/living/carbon/human/C = src
	if(ishuman(src))
		var/mob/living/carbon/human/H=src
		if(H.said_last_words)
			H.said_last_words=0
	C.stat = 0
	C.SetParalysis(0)
	C.SetStunned(0)
	C.SetKnockdown(0)
	C.lying = 0
	C.update_canmove()

	remove_changeling_verb(/obj/item/verbs/changeling/proc/changeling_unstun)
	spawn(5)
		add_changeling_verb(/obj/item/verbs/changeling/proc/changeling_unstun)
	feedback_add_details("changeling_powers","UNS")
	return 1


//Speeds up chemical regeneration
/mob/proc/changeling_fastchemical()
	var/datum/role/changeling/changeling = mind.GetRole(CHANGELING)
	changeling.chem_recharge_rate *= 2
	return 1

//Increases macimum chemical storage
/mob/proc/changeling_engorgedglands()
	var/datum/role/changeling/changeling = mind.GetRole(CHANGELING)
	changeling.chem_storage += 25
	return 1

/obj/item/verbs/changeling/proc/changeling_digitalcamo()
	set category = "Changeling"
	set name = "Toggle Digital Camouflage"
	set desc = "The AI can no longer track us. Has a constant cost while active."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_digitalcamo()

//Prevents AIs tracking you but makes you easily detectable to the human-eye.
/mob/proc/changeling_digitalcamo()
	var/datum/role/changeling/changeling = changeling_power()
	if(!changeling)
		return 0

	var/mob/living/carbon/human/C = src
	if(C.digitalcamo)
		to_chat(C, "<span class='notice'>We return to normal.</span>")
	else
		to_chat(C, "<span class='notice'>We distort our form to prevent AI-tracking.</span>")
	C.digitalcamo = !C.digitalcamo

	spawn(0)
		while(C && C.digitalcamo && C.mind && changeling && changeling.chem_charges > 5)
			changeling.chem_charges = max(changeling.chem_charges - 5, 0)
			sleep(40)
		C.digitalcamo = !C.digitalcamo
		to_chat(C, "<span class='notice'>We return to normal.</span>")

	remove_changeling_verb(/obj/item/verbs/changeling/proc/changeling_digitalcamo)
	spawn(5)
		add_changeling_verb(/obj/item/verbs/changeling/proc/changeling_digitalcamo)
	feedback_add_details("changeling_powers","CAM")
	return 1


/obj/item/verbs/changeling/proc/changeling_rapidregen()
	set category = "Changeling"
	set name = "Rapid Regeneration (30)"
	set desc = "We start rapidly regenerating over the course of 10 seconds. Stuns and chemicals are not affected, but we can use this while unconscious."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_rapidregen()

//Starts healing you every second for 10 seconds. Can be used whilst unconscious.
/mob/proc/changeling_rapidregen()
	var/datum/role/changeling/changeling = changeling_power(30,0,100,UNCONSCIOUS)
	if(!changeling)
		return 0
	changeling.chem_charges -= 30

	var/mob/living/carbon/human/C = src
	spawn(0)
		for(var/i = 0, i<10,i++)
			if(C)
				C.adjustBruteLoss(-10)
				C.adjustToxLoss(-10)
				C.adjustOxyLoss(-10)
				C.adjustFireLoss(-10)
				sleep(10)

	remove_changeling_verb(/obj/item/verbs/changeling/proc/changeling_rapidregen)
	spawn(5)
		add_changeling_verb(/obj/item/verbs/changeling/proc/changeling_rapidregen)
	feedback_add_details("changeling_powers","RR")
	return 1

// HIVE MIND UPLOAD/DOWNLOAD DNA

var/list/datum/dna/hivemind_bank = list()

/obj/item/verbs/changeling/proc/changeling_hiveupload()
	set category = "Changeling"
	set name = "Hive Channel (10)"
	set desc = "Lets us to channel DNA in the airwaves, allowing other changelings to absorb it."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_hiveupload()

/mob/proc/changeling_hiveupload()
	var/datum/role/changeling/changeling = changeling_power(10,1)
	if(!changeling)
		return

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		if(!(DNA in hivemind_bank))
			names += DNA.real_name

	if(names.len <= 0)
		to_chat(src, "<span class='notice'>The airwaves already have all of our DNA.</span>")
		return

	var/S = input("Select a DNA to channel: ", "Channel DNA", null) as null|anything in names
	if(!S)
		return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	changeling.chem_charges -= 10
	hivemind_bank += chosen_dna
	to_chat(src, "<span class='notice'>We channel the DNA of [S] to the air.</span>")
	feedback_add_details("changeling_powers","HU")
	return 1

/obj/item/verbs/changeling/proc/changeling_hivedownload()
	set category = "Changeling"
	set name = "Hive Absorb (20)"
	set desc = "Allows us to absorb DNA that is being channeled in the airwaves."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_hivedownload()

/mob/proc/changeling_hivedownload()
	var/datum/role/changeling/changeling = changeling_power(20,1)
	if(!changeling)
		return

	var/list/names = list()
	for(var/datum/dna/DNA in hivemind_bank)
		if(!(DNA in changeling.absorbed_dna))
			names[DNA.real_name] = DNA

	if(names.len <= 0)
		to_chat(src, "<span class='notice'>There's no new DNA to absorb from the air.</span>")
		return

	var/S = input("Select a DNA absorb from the air: ", "Absorb DNA", null) as null|anything in names
	if(!S)
		return
	var/datum/dna/chosen_dna = names[S]
	if(!chosen_dna)
		return

	changeling.chem_charges -= 20
	changeling.absorbed_dna += chosen_dna
	to_chat(src, "<span class='notice'>We absorb the DNA of [S] from the air.</span>")
	feedback_add_details("changeling_powers","HD")
	return 1

// Fake Voice

/obj/item/verbs/changeling/proc/changeling_mimicvoice()
	set category = "Changeling"
	set name = "Mimic Voice"
	set desc = "Shape our vocal glands to form a voice of someone we choose. We cannot regenerate chemicals when mimicing."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_mimicvoice()

/mob/proc/changeling_mimicvoice()
	if(!usr)
		return
	var/mob/user = usr
	var/datum/role/changeling/changeling = changeling_power()
	if(!changeling)
		return

	if(changeling.mimicing)
		changeling.mimicing = ""
		to_chat(src, "<span class='notice'>We return our vocal glands to their original location.</span>")
		return

	var/mimic_voice = stripped_input(user, "Enter a name to mimic.", "Mimic Voice", null, MAX_NAME_LEN)
	if(!mimic_voice)
		return

	changeling.mimicing = mimic_voice

	to_chat(src, "<span class='notice'>We shape our glands to take the voice of <b>[mimic_voice]</b>, this will stop us from regenerating chemicals while active.</span>")
	to_chat(src, "<span class='notice'>Use this power again to return to our original voice and reproduce chemicals again.</span>")

	feedback_add_details("changeling_powers","MV")

	spawn(0)
		while(src && src.mind && changeling && changeling.mimicing && changeling.chem_charges > 4)
			changeling.chem_charges = max(changeling.chem_charges - 4, 0)
			sleep(40)
		if(src && src.mind && changeling)
			to_chat(src, "<span class='notice'>Our vocal glands return to their original position.</span>")
			changeling.mimicing = ""
	//////////
	//STINGS//	//They get a pretty header because there's just so fucking many of them ;_;
	//////////

/mob/proc/sting_can_reach(mob/M as mob, sting_range = 1)
	if(M.loc == src.loc)
		return 1 //target and source are in the same thing
	if(!isturf(src.loc) || !isturf(M.loc))
		return 0 //One is inside, the other is outside something.
	if(sting_range < 2)
		return Adjacent(M)
	if(AStar(src.loc, M.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, sting_range)) //If a path exists, good!
		return 1
	return 0

//Handles the general sting code to reduce on copypasta (seeming as somebody decided to make SO MANY dumb abilities)
// allow_self=TRUE lets you sting yourself.
/mob/proc/changeling_sting(var/required_chems = 0, var/verb_path, var/allow_self = FALSE)
	var/datum/role/changeling/changeling = changeling_power(required_chems)
	if(!changeling)
		return

	var/list/victims = list()
	if(allow_self)
		victims += "(YOU)"
	for(var/mob/living/carbon/C in oview(changeling.sting_range))
		victims += C
	var/mob/living/carbon/T
	if (victims.len)
		T = victims[1]
		if (is_pacified(VIOLENCE_DEFAULT,T))
			return
		if (victims.len > 1)
			T = input(src, "Who will we sting?") as null|anything in victims
	if(!T)
		return
	if(T=="(YOU)")
		T = src
	if(!(T in view(changeling.sting_range)))
		return
	if(!sting_can_reach(T, changeling.sting_range))
		return
	if(!changeling_power(required_chems))
		return

	changeling.chem_charges -= required_chems
	changeling.sting_range = 1
	remove_changeling_verb(verb_path)
	spawn(10)
		add_changeling_verb(verb_path)

	to_chat(src, "<span class='notice'>We stealthily sting [T==src?"ourselves":"\the [T]"].</span>")
	if(!T.mind || !T.mind.GetRole(CHANGELING) || (allow_self && T == src))
		return T	//T will be affected by the sting
	to_chat(T, "<span class='warning'>You feel a tiny prick.</span>")

/obj/item/verbs/changeling/proc/changeling_chemsting()
	set category = "Changeling"
	set name = "Chemical sting (misc)"
	set desc = "Injects our victim with some chemicals, that we have sampled previously."

	var/mob/M = loc
	if(!istype(M))
		return

	var/datum/role/changeling/changeling = M.changeling_power(0)
	if(!changeling)
		return 0

	var/S = input(M, "Select the chemical: ", "Chemical IDs", null) as null|anything in changeling.known_chems //TODO: CHANGE FROM ABSORBED CHEMS INTO PURCHASED CHEMS
	if(!S)
		return

	var/bool = alert(M, "Do we wish to target ourselves?", "Yes or no, we may not know", "Yes", "No")

	var/amount = input(M, "Select how much you wish to inject. This will be how much chems we will have to muster from ourselves: ", "Chemical amount", null) as num
	if(amount == 0)
		return

	var/mob/living/carbon/target
	if (bool=="Yes")
		target = M.changeling_sting(amount, /obj/item/verbs/changeling/proc/changeling_chemsting, allow_self = TRUE)
	else
		target = M.changeling_sting(amount, /obj/item/verbs/changeling/proc/changeling_chemsting, allow_self = FALSE)
	if(!target || !target.reagents)
		return

	target.reagents.add_reagent(S, amount)

/obj/item/verbs/changeling/proc/changeling_chemspit()
	set category = "Changeling"
	set name = "Chemical spit (misc)"
	set desc = "Fires a globule of chemicals in the direction we are facing."

	var/mob/M = loc
	if(!istype(M))
		return

	var/datum/role/changeling/changeling = M.changeling_power(0)
	if(!changeling)
		return 0

	var/S = input(M, "Select the chemical: ", "Chemical IDs", null) as null|anything in changeling.known_chems //TODO: CHANGE FROM ABSORBED CHEMS INTO PURCHASED CHEMS
	if(!S)
		return

	var/amount = input(M, "Select how much you wish to spit. This will be how much chems we will have to muster from ourselves: ", "Chemical amount", null) as num
	if(amount == 0)
		return

	if(M.changeling_power(amount) && (changeling.chem_charges -= amount < 0))
		var/obj/item/projectile/puke/P = new /obj/item/projectile/puke/clear
		P.reagents.add_reagent(S, amount)
		M.visible_message("<span class = 'warning'>\The [M] spits a globule of chemicals!</span>")
		generic_projectile_fire(get_ranged_target_turf(M, M.dir, 10), M, P, 'sound/weapons/pierce.ogg')

/obj/item/verbs/changeling/proc/changeling_transformation_sting()
	set category = "Changeling"
	set name = "Transformation Sting (40)"
	set desc = "Injects our victim with some of our absorbed DNA, turning them into somebody else."

	var/mob/M = loc
	if(!istype(M))
		return

	var/datum/role/changeling/changeling = M.changeling_power(40)
	if(!changeling)
		return 0

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input(M, "Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)
		return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	var/mob/living/carbon/target = M.changeling_sting(40, /obj/item/verbs/changeling/proc/changeling_transformation_sting)
	if(!target)
		return
	if((M_HUSK in target.mutations) || (!ishuman(target) && !ismonkey(target)))
		to_chat(src, "<span class='warning'>Our sting appears ineffective against its DNA.</span>")
		return 0
	target.visible_message("<span class='warning'>[target] transforms!</span>")
	target.dna = chosen_dna.Clone()
	target.real_name = chosen_dna.real_name
	target.flavor_text = chosen_dna.flavor_text
	target.UpdateAppearance()
	domutcheck(target, null)
	feedback_add_details("changeling_powers","TS")

	return 1

/obj/item/verbs/changeling/proc/changeling_extract_dna_sting()
	set category = "Changeling"
	set name = "Extract DNA Sting (40)"
	set desc = "We stealthily sting a target and extract their DNA."

	var/mob/M = loc
	if(!istype(M) || !M.mind)
		return

	var/datum/role/changeling/changeling = M.mind.GetRole(CHANGELING)
	if(!changeling)
		return 0

	var/mob/living/carbon/human/target = M.changeling_sting(40, /obj/item/verbs/changeling/proc/changeling_extract_dna_sting)
	if(!istype(target))
		return

	target.dna.real_name = target.real_name
	target.dna.flavor_text = target.flavor_text
	changeling.absorbed_dna |= target.dna
	if(target.species && !(changeling.absorbed_species.Find(target.species.name)))
		changeling.absorbed_species += target.species.name

	feedback_add_details("changeling_powers", "ED")
	return 1

/obj/item/verbs/changeling/proc/changeling_armblade()
	set category = "Changeling"
	set name = "Generate Arm Blade (20)"
	set desc = "Transform one of our arms into a deadly blade."

	var/mob/M = loc
	if(!istype(M))
		return

	M.changeling_armblade()

/mob/proc/changeling_armblade()
	if(!istype(src, /mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = src
	if(!src.mind)
		return
	var/datum/role/changeling/changeling = mind.GetRole(CHANGELING)
	if(!changeling)
		return 0
	for(var/obj/item/weapon/armblade/W in src)
		visible_message("<span class='warning'>With a sickening crunch, [src] reforms their arm blade into an arm!</span>",
		"<span class='notice'>We assimilate the weapon back into our body.</span>",
		"<span class='italics'>You hear organic matter ripping and tearing!</span>")
		playsound(src, 'sound/weapons/bloodyslice.ogg', 30, 1)
		qdel(W)
		return 1
	var/check_chems = changeling_power(20,1)
	if(!check_chems)
		return
	var/good_hand
	if(H.can_use_hand(active_hand))
		good_hand = active_hand
	else
		for(var/i = 1 to held_items.len)
			if(H.can_use_hand(i))
				good_hand = i
				break
	if(good_hand)
		drop_item(held_items[good_hand], force_drop = 1)
		var/obj/item/weapon/armblade/A = new (src)
		put_in_hand(good_hand, A)
		H.visible_message("<span class='warning'>A grotesque blade forms around [name]\'s arm!</span>",
			"<span class='warning'>Our arm twists and mutates, transforming it into a deadly blade.</span>",
			"<span class='italics'>You hear organic matter ripping and tearing!</span>")
		playsound(H, 'sound/weapons/bloodyslice.ogg', 30, 1)
		changeling.chem_charges -= 20
		feedback_add_details("changeling_powers","AB")
		return 1
*/