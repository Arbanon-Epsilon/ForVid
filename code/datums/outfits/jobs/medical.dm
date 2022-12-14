/decl/hierarchy/outfit/job/medical
	hierarchy_type = /decl/hierarchy/outfit/job/medical
	l_ear = null
	shoes = null
	pda_type = /obj/item/device/pda/medical
	pda_slot = slot_wear_id

/decl/hierarchy/outfit/job/medical/New()
	..()
	BACKPACK_OVERRIDE_MEDICAL

/decl/hierarchy/outfit/job/medical/cmo
	name = OUTFIT_JOB_NAME("Chief Medical Officer")
	l_ear = null
	uniform = null
	shoes = null
	id_slot = slot_wear_amulet
	head = null
	suit = null
	id_type = /obj/item/weapon/card/id/medical/head
	pda_type = /obj/item/device/pda/heads/cmo

/decl/hierarchy/outfit/job/medical/doctor
	name = OUTFIT_JOB_NAME("Medical Doctor")
	l_ear = null
	uniform = null
	shoes = null
	id_slot = slot_wear_amulet
	head = null
	suit = null
	id_type = /obj/item/weapon/card/id/medical

/decl/hierarchy/outfit/job/medical/doctor/surgeon
	name = OUTFIT_JOB_NAME("Surgeon")
	uniform = null
	head = null

/decl/hierarchy/outfit/job/medical/doctor/virologist
	name = OUTFIT_JOB_NAME("Virologist")
	uniform = /obj/item/clothing/under/rank/virologist
	suit = /obj/item/clothing/suit/storage/toggle/labcoat/virologist
	mask = /obj/item/clothing/mask/surgical
/decl/hierarchy/outfit/job/medical/doctor/virologist/New()
	..()
	BACKPACK_OVERRIDE_VIROLOGY

/decl/hierarchy/outfit/job/medical/doctor/nurse
	name = OUTFIT_JOB_NAME("Nurse")
	suit = null

/decl/hierarchy/outfit/job/medical/doctor/nurse/pre_equip(mob/living/carbon/human/H)
	..()
	if(H.gender == FEMALE)
		if(prob(50))
			uniform = /obj/item/clothing/under/rank/nursesuit
		else
			uniform = /obj/item/clothing/under/rank/nurse
		head = /obj/item/clothing/head/nursehat
	else
		uniform = /obj/item/clothing/under/rank/medical/scrubs/purple
		head = null

/decl/hierarchy/outfit/job/medical/chemist
	name = OUTFIT_JOB_NAME("Chemist")
	uniform = /obj/item/clothing/under/rank/chemist
	suit = /obj/item/clothing/suit/storage/toggle/labcoat/chemist
	id_type = /obj/item/weapon/card/id/medical
	pda_type = /obj/item/device/pda/chemist

/decl/hierarchy/outfit/job/medical/chemist/New()
	..()
	BACKPACK_OVERRIDE_VIROLOGY

/decl/hierarchy/outfit/job/medical/geneticist
	name = OUTFIT_JOB_NAME("Geneticist")
	uniform = /obj/item/clothing/under/rank/geneticist
	suit = /obj/item/clothing/suit/storage/toggle/labcoat/genetics
	r_pocket = /obj/item/device/flashlight/pen
	id_type = /obj/item/weapon/card/id/medical/geneticist
	pda_type = /obj/item/device/pda/geneticist

/decl/hierarchy/outfit/job/medical/geneticist/New()
	..()
	backpack_overrides[/decl/backpack_outfit/backpack] = /obj/item/weapon/storage/backpack/genetics
	backpack_overrides[/decl/backpack_outfit/satchel]  = /obj/item/weapon/storage/backpack/satchel_gen

/decl/hierarchy/outfit/job/medical/psychiatrist
	name = OUTFIT_JOB_NAME("Psychiatrist")
	uniform = /obj/item/clothing/under/rank/psych
	suit = /obj/item/clothing/suit/storage/toggle/labcoat
	shoes = /obj/item/clothing/shoes/laceup
	id_type = /obj/item/weapon/card/id/medical/psychiatrist

/decl/hierarchy/outfit/job/medical/psychiatrist/psychologist
	name = OUTFIT_JOB_NAME("Psychologist")
	uniform = /obj/item/clothing/under/rank/psych/turtleneck

/decl/hierarchy/outfit/job/medical/paramedic
	name = OUTFIT_JOB_NAME("Paramedic")
	uniform = /obj/item/clothing/under/rank/medical/scrubs/black
	shoes = /obj/item/clothing/shoes/jackboots
	l_hand = /obj/item/weapon/storage/firstaid/adv
	belt = /obj/item/weapon/storage/belt/medical/emt
	id_type = /obj/item/weapon/card/id/medical/paramedic
	flags = OUTFIT_HAS_BACKPACK|OUTFIT_EXTENDED_SURVIVAL

/decl/hierarchy/outfit/job/medical/paramedic/emt
	name = OUTFIT_JOB_NAME("Emergency medical technician")
	uniform = /obj/item/clothing/under/rank/medical/paramedic
