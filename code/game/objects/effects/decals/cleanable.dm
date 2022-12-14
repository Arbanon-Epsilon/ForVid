/obj/effect/decal/cleanable
	waterproof = FALSE
	var/persistent = FALSE
	var/generic_filth = FALSE
	var/age = 0
	var/list/random_icon_states
	layer = DECAL_LAYER

/obj/effect/decal/cleanable/Initialize(var/ml, var/_age)
	if(random_icon_states && length(src.random_icon_states) > 0)
		src.icon_state = pick(src.random_icon_states)
	if(!ml)
		if(!isnull(_age))
			age = _age
		SSpersistence.track_value(src, /datum/persistent/filth)
	. = ..()

/obj/effect/decal/cleanable/Destroy()
	SSpersistence.forget_value(src, /datum/persistent/filth)
	. = ..()

/obj/effect/decal/cleanable/clean_blood(var/ignore = 0)
	if(!ignore)
		qdel(src)
		return
	..()

/obj/effect/decal/cleanable/water_act(var/depth)
	..()
	qdel(src)
