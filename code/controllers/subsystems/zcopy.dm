
#define SHADOWER_DARKENING_FACTOR 0.6	// The multiplication factor for openturf shadower darkness. Lighting will be multiplied by this.

SUBSYSTEM_DEF(zcopy)
	name = "Z-Copy"
	wait = 1
	init_order = SS_INIT_ZCOPY
	priority = SS_PRIORITY_ZCOPY
	runlevels = RUNLEVELS_DEFAULT | RUNLEVEL_LOBBY

	var/list/queued_turfs = list()
	var/qt_idex = 1
	var/list/queued_overlays = list()
	var/qo_idex = 1

	var/openspace_overlays = 0
	var/openspace_turfs = 0

	// Highest Z level in a given Z-group for absolute layering used by FIX_BIGTURF.
	// zstm[zlev] = group_max
	var/list/zstack_maximums = list()

	// Caches for fixup.
	var/list/fixup_cache = list()
	var/list/fixup_known_good = list()

	// Fixup stats.
	var/fixup_miss = 0
	var/fixup_noop = 0
	var/fixup_hit = 0


// for admin proc-call
/datum/controller/subsystem/zcopy/proc/update_all()
	disable()
	log_debug("SSzcopy: update_all() invoked.")

	var/turf/T 	// putting the declaration up here totally speeds it up, right?
	var/num_upd = 0
	var/num_del = 0
	var/num_amupd = 0
	for (var/atom/A in world)
		if (isturf(A))
			T = A
			if (T.z_flags & ZM_MIMIC_BELOW)
				T.update_mimic()
				num_upd += 1

		else if (istype(A, /atom/movable/openspace/overlay))
			var/turf/Tloc = A.loc
			if (TURF_IS_MIMICING(Tloc))
				Tloc.update_mimic()
				num_amupd += 1
			else
				qdel(A)
				num_del += 1

		CHECK_TICK

	log_debug("SSzcopy: [num_upd + num_amupd] turf updates queued ([num_upd] direct, [num_amupd] indirect), [num_del] orphans destroyed.")

	enable()

// for admin proc-call
/datum/controller/subsystem/zcopy/proc/hard_reset()
	disable()
	log_debug("SSzcopy: hard_reset() invoked.")
	var/num_deleted = 0
	var/num_turfs = 0

	var/turf/T
	for (var/atom/A in world)
		if (isturf(A))
			T = A
			if (T.z_flags & ZM_MIMIC_BELOW)
				T.update_mimic()
				num_turfs += 1

		else if (istype(A, /atom/movable/openspace/overlay))
			qdel(A)
			num_deleted += 1

		CHECK_TICK

	log_debug("SSzcopy: deleted [num_deleted] overlays, and queued [num_turfs] turfs for update.")

	enable()

/datum/controller/subsystem/zcopy/stat_entry()
	..("Q:{T:[queued_turfs.len - (qt_idex - 1)]|O:[queued_overlays.len - (qo_idex - 1)]} T:{T:[openspace_turfs]|O:[openspace_overlays]}")

/datum/controller/subsystem/zcopy/Initialize(timeofday)
	calculate_zstack_limits()
	// Flush the queue.
	fire(FALSE, TRUE)
	return ..()

// If you add a new Zlevel or change Z-connections, call this.
/datum/controller/subsystem/zcopy/proc/calculate_zstack_limits()
	zstack_maximums = new(world.maxz)
	var/start_zlev = 1
	for (var/z in 1 to world.maxz)
		if (!HasAbove(z))
			for (var/member_zlev in start_zlev to z)
				zstack_maximums[member_zlev] = z
			start_zlev = z + 1

	log_ss("zcopy", "Z-Stack maximums: [json_encode(zstack_maximums)]")

/datum/controller/subsystem/zcopy/StartLoadingMap()
	suspend()

/datum/controller/subsystem/zcopy/StopLoadingMap()
	wake()


/datum/controller/subsystem/zcopy/fire(resumed = FALSE, no_mc_tick = FALSE)
	if (!resumed)
		qt_idex = 1
		qo_idex = 1

	MC_SPLIT_TICK_INIT(2)
	if (!no_mc_tick)
		MC_SPLIT_TICK

	var/list/curr_turfs = queued_turfs
	var/list/curr_ov = queued_overlays

	while (qt_idex <= curr_turfs.len)
		var/turf/T = curr_turfs[qt_idex]
		curr_turfs[qt_idex] = null
		qt_idex += 1

		if (!isturf(T) || !T.below || !(T.z_flags & ZM_MIMIC_BELOW))
			if (no_mc_tick)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				break
			continue

		if (!T.shadower)	// If we don't have a shadower yet, something has gone horribly wrong.
			WARNING("Turf [T] at [T.x],[T.y],[T.z] was queued, but had no shadower.")
			continue

		// Figure out how many z-levels down we are.
		var/depth = 0
		var/turf/Td = T

		while (Td.below)
			Td = Td.below

		T.z_depth = depth = min(T.z - Td.z, OPENTURF_MAX_DEPTH)

		var/t_target = OPENTURF_MAX_PLANE - depth	// this is where the openturf gets put

		// Handle space parallax.
		if (T.below.z_eventually_space)
			T.z_eventually_space = TRUE
			t_target = SPACE_PLANE

		if (T.below.z_flags & ZM_FIX_BIGTURF)
			T.z_flags |= ZM_FIX_BIGTURF	// this flag is infectious

		// There's no point creating TOs for space, it'll draw under the Z-turf anyways.
		if (!T.below.z_eventually_space || (T.z_flags & ZM_MIMIC_OVERWRITE))
			if (T.z_flags & ZM_MIMIC_OVERWRITE)
				// This openturf doesn't care about its icon, so we can just overwrite it.
				if (T.below.bound_overlay)
					QDEL_NULL(T.below.bound_overlay)
				T.appearance = T.below
				T.name = initial(T.name)
				T.desc = initial(T.desc)
				T.gender = initial(T.gender)
				T.opacity = FALSE
				T.plane = t_target
			else
				// Some openturfs have icons, so we can't overwrite their appearance.
				if (!T.below.bound_overlay)
					T.below.bound_overlay = new(T)
				var/atom/movable/openspace/turf_overlay/TO = T.below.bound_overlay
				TO.appearance = T.below
				TO.name = T.name
				TO.gender = T.gender	// Need to grab this too so PLURAL works properly in examine.
				TO.opacity = FALSE
				TO.plane = t_target

		else if (T.below.bound_overlay)
			QDEL_NULL(T.below.bound_overlay)

		T.queue_ao()	// TODO: non-rebuild updates seem to break pixel offsets, but should work in theory if that's fixed?

		// Add everything below us to the update queue.
		for (var/thing in T.below)
			var/atom/movable/object = thing
			if (QDELETED(object) || (object.z_flags & ZMM_IGNORE) || object.loc != T.below || object.invisibility == INVISIBILITY_ABSTRACT)
				// Don't queue deleted stuff, stuff that's not visible, blacklisted stuff, or stuff that's centered on another tile but intersects ours.
				continue

			// Special case: these are merged into the shadower to reduce memory usage.
			if (object.type == /atom/movable/lighting_overlay)
				// T.shadower.copy_lighting(object)
			else
				if (!object.bound_overlay)	// Generate a new overlay if the atom doesn't already have one.
					object.bound_overlay = new(T)
					object.bound_overlay.associated_atom = object

				var/override_depth
				var/original_type = object.type
				switch (object.type)
					if (/atom/movable/openspace/overlay)
						var/atom/movable/openspace/overlay/OOO = object
						original_type = OOO.mimiced_type
						override_depth = OOO.override_depth

					if (/atom/movable/openspace/multiplier)
						// Large turfs require special (read: broken) layering to not look awful.
						// This isn't enabled on other turfs that can layer normally as it breaks atom/shadower layer order (causing them to be lighter than intended.)
						if (T.z_flags & ZM_FIX_BIGTURF)
							override_depth = min((zstack_maximums[T.z] - object.z) + 1, OPENTURF_MAX_DEPTH)

					if (/atom/movable/openspace/turf_overlay)
						// If we're a turf overlay (the mimic for a non-OVERWRITE turf), we need to make sure copies of us respect space parallax too
						if (T.z_eventually_space)
							// Yes, this is an awful hack; I don't want to add yet another override_* var.
							override_depth = OPENTURF_MAX_PLANE - SPACE_PLANE

				var/atom/movable/openspace/overlay/OO = object.bound_overlay

				// If the OO was queued for destruction but was claimed by another OT, stop the destruction timer.
				if (OO.destruction_timer)
					deltimer(OO.destruction_timer)
					OO.destruction_timer = null

				OO.depth = override_depth || min(T.z - object.z, OPENTURF_MAX_DEPTH)
				OO.mimiced_type = original_type
				OO.override_depth = override_depth

				if (!OO.queued)
					OO.queued = TRUE
					queued_overlays += OO

		T.z_queued -= 1
		if (!no_mc_tick && T.above)
			T.above.update_mimic()

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break

	if (qt_idex > 1)
		curr_turfs.Cut(1, qt_idex)
		qt_idex = 1

	if (!no_mc_tick)
		MC_SPLIT_TICK

	while (qo_idex <= curr_ov.len)
		var/atom/movable/openspace/overlay/OO = curr_ov[qo_idex]
		curr_ov[qo_idex] = null
		qo_idex += 1

		if (QDELETED(OO))
			if (no_mc_tick)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				break
			continue

		if (QDELETED(OO.associated_atom))	// This shouldn't happen, but just in-case.
			qdel(OO)

			if (no_mc_tick)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				break
			continue

		// Actually update the overlay.
		if (OO.dir != OO.associated_atom.dir)
			OO.set_dir(OO.associated_atom.dir)

		OO.appearance = OO.associated_atom
		OO.z_flags = OO.associated_atom.z_flags
		OO.plane = OPENTURF_MAX_PLANE + OO.depth

		OO.opacity = FALSE
		OO.queued = 0

		// If an atom has explicit plane sets on its overlays/underlays, we need to replace the appearance so they can be mangled to work with our planing.
		if (OO.z_flags & ZMM_MANGLE_PLANES)
			var/new_appearance = fixup_appearance_planes(OO.appearance)
			if (new_appearance)
				OO.appearance = new_appearance

		if (OO.bound_overlay)	// If we have a bound overlay, queue it too.
			OO.update_above()

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break

		if (qo_idex > 1)
			curr_ov.Cut(1, qo_idex)
			qo_idex = 1

// Recurse: for self, check if planes are invalid, if yes; return fixed appearance
// For each of overlay,underlay, call fixup_appearance_planes; if it returns a new appearance, replace self

/// Generate a new appearance from `appearance` with planes mangled to work with Z-Mimic. Do not pass a depth.
/datum/controller/subsystem/zcopy/proc/fixup_appearance_planes(appearance, depth = 0)
	if (fixup_known_good[appearance])
		fixup_hit += 1
		return null
	if (fixup_cache[appearance])
		fixup_hit += 1
		return fixup_cache[appearance]

	// If you have more than 4 layers of overlays within overlays, I dunno what to say.
	if (depth > 4)
		var/icon_name = "[appearance:icon]"
		WARNING("Fixup of appearance with icon [icon_name || "<unknown file>"] exceeded maximum recursion limit, bailing")
		return null

	var/plane_needs_fix = FALSE

	// Don't fixup the root object's plane.
	if (depth > 0)
		switch (appearance:plane)
			if (DEFAULT_PLANE, FLOAT_PLANE)
				// fine
			else
				plane_needs_fix = TRUE

	// Scan & fix overlays
	var/list/fixed_overlays
	if (appearance:overlays:len)
		var/mutated = FALSE
		var/fixed_appearance
		for (var/i in 1 to appearance:overlays:len)
			if ((fixed_appearance = .(appearance:overlays[i], depth + 1)))
				mutated = TRUE
				if (!fixed_overlays)
					fixed_overlays = new(appearance:overlays.len)
				fixed_overlays[i] = fixed_appearance

		if (mutated)
			for (var/i in 1 to fixed_overlays.len)
				if (fixed_overlays[i] == null)
					fixed_overlays[i] = appearance:overlays[i]

	// Scan & fix underlays
	var/list/fixed_underlays
	if (appearance:underlays:len)
		var/mutated = FALSE
		var/fixed_appearance
		for (var/i in 1 to appearance:underlays:len)
			if ((fixed_appearance = .(appearance:underlays[i], depth + 1)))
				mutated = TRUE
				if (!fixed_underlays)
					fixed_underlays = new(appearance:underlays.len)
				fixed_underlays[i] = fixed_appearance

		if (mutated)
			for (var/i in 1 to fixed_overlays.len)
				if (fixed_underlays[i] == null)
					fixed_underlays[i] = appearance:underlays[i]

	// If we did nothing (no violations), don't bother creating a new appearance
	if (!plane_needs_fix && !fixed_overlays && !fixed_underlays)
		fixup_noop += 1
		fixup_known_good[appearance] = TRUE
		return null

	fixup_miss += 1

	var/mutable_appearance/MA = new(appearance)
	if (plane_needs_fix)
		MA.plane = depth == 0 ? DEFAULT_PLANE : FLOAT_PLANE
		MA.layer = FLY_LAYER	// probably fine

	if (fixed_overlays)
		MA.overlays = fixed_overlays

	if (fixed_underlays)
		MA.underlays = fixed_underlays

	fixup_cache[appearance] = MA.appearance

	return MA

/client/proc/analyze_openturf(turf/T)
	set name = "Analyze Openturf"
	set desc = "Show the layering of an openturf and everything it's mimicking."
	set category = "Debug"

	if (!check_rights(R_DEBUG))
		return

	var/list/out = list(
		"<h1>Analysis of [T] at [T.x],[T.y],[T.z]</h1>",
		"<b>Queue occurrences:</b> [T.z_queued]",
		"<b>Above space:</b> Apparent [T.z_eventually_space ? "Yes" : "No"], Actual [T.is_above_space() ? "Yes" : "No"]",
		"<b>Z Flags</b>: [english_list(bitfield2list(T.z_flags, global.mimic_defines), "(none)")]",
		"<b>Has Shadower:</b> [T.shadower ? "Yes" : "No"]",
		"<b>Below:</b> [!T.below ? "(nothing)" : "[T.below] at [T.below.x],[T.below.y],[T.below.z]"]",
		"<b>Depth:</b> [T.z_depth == null ? "(null)" : T.z_depth] [T.z_depth == OPENTURF_MAX_DEPTH ? "(max)" : ""]",
		"<ul>"
	)

	var/list/found_oo = list(T)
	for (var/thing in T)
		if (istype(thing, /atom/movable/openspace))
			found_oo += thing

	var/turf/Td = T
	while (Td.below)
		Td = Td.below
		found_oo += Td

	sortTim(found_oo, /proc/cmp_planelayer)
	for (var/thing in found_oo)
		var/atom/A = thing
		if (istype(A, /atom/movable/openspace/overlay))
			var/atom/movable/openspace/overlay/OO = A
			var/atom/movable/AA = OO.associated_atom
			out += "<li>\icon[A] plane [A.plane], layer [A.layer], depth [OO.depth], associated Z-level [AA.z] - [OO.type] copying [AA] ([AA.type], eventually [OO.mimiced_type])</li>"
		else if (isturf(A))
			if (A == T)
				out += "<li>\icon[A] plane [A.plane], layer [A.layer], depth [A:z_depth], Z-level [A.z] - [A] ([A.type]) - <font color='green'>SELF</font></li>"
			else	// foreign turfs - not visible here, but good for figuring out layering
				out += "<li>\icon[A] plane [A.plane], layer [A.layer], depth [A:z_depth], Z-level [A.z] - [A] ([A.type]) - <font color='red'>FOREIGN</font></li>"
		else
			out += "<li>\icon[A] plane [A.plane], layer [A.layer], Z-level [A.z] - [A] ([A.type])</li>"

	out += "</ul>"

	show_browser(usr, out.Join("<br>"), "size=980x580;window=openturfanalysis-\ref[T]")
