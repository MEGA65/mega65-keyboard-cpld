prj_project open "megakey.ldf"
prj_run Synthesis -impl impl1
prj_run Translate -impl impl1
prj_run Map -impl impl1
prj_run PAR -impl impl1
prj_run PAR -impl impl1 -task PARTrace
prj_run Export -impl impl1 -task Bitgen
prj_run Export -impl impl1 -task Jedecgen
prj_project close
