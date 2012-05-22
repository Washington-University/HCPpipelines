import sys, os

def main():
	#initialize dictionaries		
	ev_length = dict([('EV_BIOMOT',12),('EV_GAMBBR1',64),('EV_GAMBBR2',64),
			('EV_GAMBER1',64),('EV_GAMBER2',64),
			('EV_HAMMER1',9),('EV_HAMMER2',9),
			('EV_IAPS1',80),('EV_IAPS2',80),
			('EV_MOTOR',16),
			('EV_POSNBR1',10),('EV_POSNBR2',10),('EV_POSNER1',76),('EV_POSNER2',76),
			('EV_RECOG1',48),('EV_RECOG2',48),('EV_RECOG3',48),('EV_RECOG4',48),
			('EV_SENT1',36),('EV_SENT2',36),
			('EV_SOCIAL1',10),('EV_SOCIAL2',10),
			('EV_WM1',80),('EV_WM2',80),('EV_WM3',80),('EV_WM4',80)])
			
	ev_files = dict([('EV_BIOMOT',['biomot.txt','rndmot.txt']),
			('EV_GAMBBR1',['loss_event.txt','neut.txt','win_event.txt']),('EV_GAMBBR2',['loss_event.txt','neut.txt','win_event.txt']),
			('EV_GAMBER1',['loss.txt','neut.txt','win.txt']),('EV_GAMBER2',['loss.txt','neut.txt','win.txt']),
			('EV_HAMMER1',['fear.txt','neut.txt']),('EV_HAMMER2',['fear.txt','neut.txt']),
			('EV_IAPS1',['neg_event.txt','neut_event.txt']),('EV_IAPS2',['neg_event.txt','neut_event.txt']),
			('EV_MOTOR',['lf.txt','lh.txt','rf.txt','rh.txt','t.txt']),
			('EV_POSNBR1',['inv.txt','val.txt']),('EV_POSNBR2',['inv.txt','val.txt']),
			('EV_POSNER1',['inv.txt','val.txt']),('EV_POSNER2',['inv.txt','val.txt']),
			('EV_RECOG1',['faces.txt','places.txt']),('EV_RECOG2',['faces.txt','places.txt']),
			('EV_RECOG3',['faces.txt','places.txt']),('EV_RECOG4',['faces.txt','places.txt']),
			('EV_SENT1',['syn.txt','sem.txt','prag.txt','ctrl.txt']),('EV_SENT2',['syn.txt','sem.txt','prag.txt','ctrl.txt']),
			('EV_SOCIAL1',['mental.txt','rnd.txt']),('EV_SOCIAL2',['mental.txt','rnd.txt']),
			('EV_WM1',['0bk_cor.txt','0bk_err.txt','2bk_cor.txt','2bk_err.txt']),('EV_WM2',['0bk_cor.txt','0bk_err.txt','2bk_cor.txt','2bk_err.txt']),
			('EV_WM3',['0bk_cor.txt','0bk_err.txt','2bk_cor.txt','2bk_err.txt']),('EV_WM4',['0bk_cor.txt','0bk_err.txt','2bk_cor.txt','2bk_err.txt'])])
	
	
	ev_durration = dict([('EV_BIOMOT',374.01),
			('EV_GAMBBR1',352),('EV_GAMBBR2',352),
			('EV_GAMBER1',296),('EV_GAMBER2',296),
			('EV_HAMMER1',205),('EV_HAMMER2',205),
			('EV_IAPS1',358),('EV_IAPS2',358),
			('EV_MOTOR',327.43),
			('EV_POSNBR1',358),('EV_POSNBR2',358),
			('EV_POSNER1',350),('EV_POSNER2',350),
			('EV_RECOG1',292),('EV_RECOG2',292),
			('EV_RECOG3',292),('EV_RECOG4',292),
			('EV_SENT1',367.16),('EV_SENT2',367.16),
			('EV_SOCIAL1',391.82),('EV_SOCIAL2',391.82),
			('EV_WM1',291.81),('EV_WM2',291.81),
			('EV_WM3',291.81),('EV_WM4',291.81)])
			
	
	exc_list = []		
	Sync_Val = None
	
	#accepts Session (CP100XX_vX) directory
	directory = sys.argv[1]
	#split directory by / to get session alone
	session = directory.split('/')
	#grab just the sesion name
	session = session[2]

#	Alternate way of coding durations	
#	proc = subprocess.Popen('fslval $PILOT/fmri/subjects/'+session+'/BOLDRECOG'+str(i)+' dim4', stdout=subprocess.PIPE, shell=True)
#	(value, err) = proc.communicate()
#	last_run_volumes = int(value)
	
	#map directory (should fetch all EV_ folders)
	dirList = os.listdir(directory)
	#iterate through EV_ folders
	for folder in dirList:
		if folder[:2] == "EV":
			#clear max_onset
			max_onset = 0.0
			#clear task durration
			task_durr = 0.0
			#clear text_count
			text_count = []
			#generate empty text file in EV_ folder
			ev_check_data = open(directory + "/" + folder + '/ev_log.txt','w')
			#iterate through folders and grab txt files based on keys
			curr_dir = ev_files[folder]
			#iterate through files and open
			for textfile in curr_dir:
				#open textfile
				curr_text = open(directory + "/" + folder+ "/" + textfile,'r')
				#readlines
				tmp = curr_text.readlines()
				#iterate through tmp append to text_count
				for line in tmp:
					#append the line to text_count
					text_count.append(line.rstrip())
					#split the line by tab
					line = line.split("\t")
					#assign task_durr
					task_durr = float(line[1])
					#if the current line is greater than the greatest onset thus far
					if float(line[0]) > max_onset:
						#replace the greatest onset with the current onset
						max_onset = float(line[0])
						
			#grab Sync.txt and assign sync_val
			Sync_Txt = open(directory+'/'+folder+'/Sync.txt','r')
			Sync_Val = Sync_Txt.readline().strip()
						
			FFTR = open(directory+"/"+folder+'/restOnset.txt','r')
			
			if exc_list.count(str(session)) == 0:
				restOnsetTime = FFTR.readline()
				restOnsetTime = (float(restOnsetTime) - float(Sync_Val))
				#after all text files have been read, check that max_onset + durration <= ev_duration
				if ev_durration[folder] >= restOnsetTime:
					ev_check_data.write("IN BOUNDS\n")
				else:
					ev_check_data.write("WARNING: OUT OF BOUNDS\n")
					ev_check_data.write(str(ev_durration[folder])+"\n")
					ev_check_data.write(str(restOnsetTime)+"\n")
					ev_check_data.write("Exceeded by: "+str(float(restOnsetTime-ev_durration[folder]))+"ms\n")
				
				ev_check_data.write("--------------\n")
				
			elif exc_list.count(str(session)) > 0:
				#after all text files have been read, check that max_onset + durration <= ev_duration
				if ev_durration[folder] >= max_onset+task_durr:
					ev_check_data.write("IN BOUNDS\n")
				else:
					ev_check_data.write("WARNING: OUT OF BOUNDS\n")
					ev_check_data.write(str(ev_durration[folder])+"\n")
					ev_check_data.write(str(max_onset+task_durr)+"\n")
					ev_check_data.write("Exceeded by: "+str(float((max_onset+taskdurr)-ev_durration[folder]))+"ms\n")

				ev_check_data.write("--------------\n")
									
			#after all text files have been read, get text_count length
			text_count = len(text_count)
			if ev_length[folder] == text_count:
				ev_check_data.write("PASSED\n")
			else:
				ev_check_data.write("WARNING: FAILED\n")
				ev_check_data.write(str(ev_length[folder])+'\n')
				ev_check_data.write(str(text_count)+'\n')				
		
if __name__ == "__main__":
	main()