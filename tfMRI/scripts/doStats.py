import sys, os

def main():
	#initialize variables
	sessionID = ''
	GAMBBR_stats = [ [], [] ]
	GAMBER_stats = [ [], [] ]
	HAMMER_stats = [ [], [] ]
	IAPS_stats = [ [], [] ]
	POSNBR_stats = [ [], [] ]
	POSNER_stats = [ [], [] ]
	RECOG_stats = [ [], [], [], [] ]	
	SENT_stats = [ [], [] ]
	WM_stats = [ [], [], [], [] ]
	SOCIAL_stats = [ [], [] ]
	
	session_line = []
	session_string = ''
	headline_string = ''
	varr_list = []
	
	headline = ['Session',
				'GAMBBR1_MeanRT','GAMBBR1_PctNLR','GAMBBR1_ACC','GAMBBR2_MeanRT','GAMBBR2_PctNLR','GAMBBR2_ACC',
				'GAMBER1_MeanRT','GAMBER1_PctNLR','GAMBER1_ACC','GAMBER2_MeanRT','GAMBER2_PctNLR','GAMBER2_ACC',
				'HAMMER1_ACC_Face', 'HAMMER1_ACC_Shape', 'HAMMER1_MeanRT_Face', 'HAMMER1_MeanRT_Shape',
				'HAMMER2_ACC_Face', 'HAMMER2_ACC_Shape', 'HAMMER2_MeanRT_Face', 'HAMMER2_MeanRT_Shape',
				'IAPS1_PctNegt_Negt', 'IAPS1_PctNegt_Neu', 'IAPS2_PctNegt_Negt','IAPS2_PctNegt_Neu',
				'POSNBR1_ACC_Inv', 'POSNBR1_ACC_Val','POSNBR1_MeanRT_Inv', 'POSNBR1_MeanRT_Val',
				'POSNBR2_ACC_Inv', 'POSNBR2_ACC_Val','POSNBR2_MeanRT_Inv', 'POSNBR2_MeanRT_Val',
				'POSNER1_ACC_Inv', 'POSNER1_ACC_Val','POSNER1_MeanRT_Inv', 'POSNER1_MeanRT_Val',
				'POSNER2_ACC_Inv', 'POSNER2_ACC_Val','POSNER2_MeanRT_Inv', 'POSNER2_MeanRT_Val',
				'RECOG1_ACC_NewFace', 'RECOG1_ACC_NewPlace', 'RECOG1_PctKnow_OldFace', 'RECOG1_PctKnow_OldPlace', 'RECOG1_PctRem_OldFace', 'RECOG1_PctRem_OldPlace', 'RECOG1_MeanRT_KnowOldFace', 'RECOG1_MeanRT_KnowOldPlace', 'RECOG1_MeanRT_NewFace', 'RECOG1_MeanRT_NewPlace', 'RECOG1_MeanRT_RemOldFace', 'RECOG1_MeanRT_RemOldPlace','RECOG1_PctNLR',
				'RECOG2_ACC_NewFace', 'RECOG2_ACC_NewPlace', 'RECOG2_PctKnow_OldFace', 'RECOG2_PctKnow_OldPlace', 'RECOG2_PctRem_OldFace', 'RECOG2_PctRem_OldPlace', 'RECOG2_MeanRT_KnowOldFace', 'RECOG2_MeanRT_KnowOldPlace', 'RECOG2_MeanRT_NewFace', 'RECOG2_MeanRT_NewPlace', 'RECOG2_MeanRT_RemOldFace', 'RECOG2_MeanRT_RemOldPlace','RECOG2_PctNLR',
				'RECOG3_ACC_NewFace', 'RECOG3_ACC_NewPlace', 'RECOG3_PctKnow_OldFace', 'RECOG3_PctKnow_OldPlace', 'RECOG3_PctRem_OldFace', 'RECOG3_PctRem_OldPlace', 'RECOG3_MeanRT_KnowOldFace', 'RECOG3_MeanRT_KnowOldPlace', 'RECOG3_MeanRT_NewFace', 'RECOG3_MeanRT_NewPlace', 'RECOG3_MeanRT_RemOldFace', 'RECOG3_MeanRT_RemOldPlace','RECOG3_PctNLR',
				'RECOG4_ACC_NewFace', 'RECOG4_ACC_NewPlace', 'RECOG4_PctKnow_OldFace', 'RECOG4_PctKnow_OldPlace', 'RECOG4_PctRem_OldFace', 'RECOG4_PctRem_OldPlace', 'RECOG4_MeanRT_KnowOldFace', 'RECOG4_MeanRT_KnowOldPlace', 'RECOG4_MeanRT_NewFace', 'RECOG4_MeanRT_NewPlace', 'RECOG4_MeanRT_RemOldFace', 'RECOG4_MeanRT_RemOldPlace','RECOG4_PctNLR',
				'SENT1_ACC_Ctrl', 'SENT1_MeanRT_Ctrl', 'SENT1_ACC_Prag', 'SENT1_MeanRT_Prag', 'SENT1_ACC_Sem', 'SENT1_MeanRT_Sem', 'SENT1_ACC_Syn', 'SENT1_MeanRT_Syn',
				'SENT2_ACC_Ctrl', 'SENT2_MeanRT_Ctrl', 'SENT2_ACC_Prag', 'SENT2_MeanRT_Prag', 'SENT2_ACC_Sem', 'SENT2_MeanRT_Sem', 'SENT2_ACC_Syn', 'SENT2_MeanRT_Syn',
				'SOCIAL1_MeanRT', 'SOCIAL1_PctInteract', 'SOCIAL1_PctRandom', 'SOCIAL1_PctUnsure', 'SOCIAL1_PctNLR',
				'SOCIAL2_MeanRT', 'SOCIAL2_PctInteract', 'SOCIAL2_PctRandom', 'SOCIAL2_PctUnsure', 'SOCIAL2_PctNLR',
				'WM1_ACC_0BackBody', 'WM1_ACC_0BackFace', 'WM1_ACC_0BackPlace', 'WM1_ACC_0BackTools', 'WM1_ACC_2BackBody', 'WM1_ACC_2BackFace', 'WM1_ACC_2BackPlace', 'WM1_ACC_2BackTools', 'WM1_MeanRT_0BackBody', 'WM1_MeanRT_0BackFace', 'WM1_MeanRT_0BackPlace', 'WM1_MeanRT_0BackTools', 'WM1_MeanRT_2BackBody', 'WM1_MeanRT_2BackFace', 'WM1_MeanRT_2BackPlace', 'WM1_MeanRT_2BackTools',
				'WM2_ACC_0BackBody', 'WM2_ACC_0BackFace', 'WM2_ACC_0BackPlace', 'WM2_ACC_0BackTools', 'WM2_ACC_2BackBody', 'WM2_ACC_2BackFace', 'WM2_ACC_2BackPlace', 'WM2_ACC_2BackTools', 'WM2_MeanRT_0BackBody', 'WM2_MeanRT_0BackFace', 'WM2_MeanRT_0BackPlace', 'WM2_MeanRT_0BackTools', 'WM2_MeanRT_2BackBody', 'WM2_MeanRT_2BackFace', 'WM2_MeanRT_2BackPlace', 'WM2_MeanRT_2BackTools',
				'WM3_ACC_0BackBody', 'WM3_ACC_0BackFace', 'WM3_ACC_0BackPlace', 'WM3_ACC_0BackTools', 'WM3_ACC_2BackBody', 'WM3_ACC_2BackFace', 'WM3_ACC_2BackPlace', 'WM3_ACC_2BackTools', 'WM3_MeanRT_0BackBody', 'WM3_MeanRT_0BackFace', 'WM3_MeanRT_0BackPlace', 'WM3_MeanRT_0BackTools', 'WM3_MeanRT_2BackBody', 'WM3_MeanRT_2BackFace', 'WM3_MeanRT_2BackPlace', 'WM3_MeanRT_2BackTools',
				'WM4_ACC_0BackBody', 'WM4_ACC_0BackFace', 'WM4_ACC_0BackPlace', 'WM4_ACC_0BackTools', 'WM4_ACC_2BackBody', 'WM4_ACC_2BackFace', 'WM4_ACC_2BackPlace', 'WM4_ACC_2BackTools', 'WM4_MeanRT_0BackBody', 'WM4_MeanRT_0BackFace', 'WM4_MeanRT_0BackPlace', 'WM4_MeanRT_0BackTools', 'WM4_MeanRT_2BackBody', 'WM4_MeanRT_2BackFace', 'WM4_MeanRT_2BackPlace', 'WM4_MeanRT_2BackTools'
				]	
				
	#create csv string from healine
	for item in headline:
		headline_string = headline_string + "\t" + str(item)
	
	#build dictionary, pairing task to stats
	task_pairs = dict([('EV_GAMBBR1',GAMBBR_stats[0]),('EV_GAMBBR2',GAMBBR_stats[1]),
		('EV_GAMBER1',GAMBER_stats[0]),('EV_GAMBER2',GAMBER_stats[1]),
		('EV_HAMMER1',HAMMER_stats[0]),('EV_HAMMER2',HAMMER_stats[1]),
		('EV_IAPS1',IAPS_stats[0]),('EV_IAPS2',IAPS_stats[1]),
		('EV_POSNBR1',POSNBR_stats[0]),('EV_POSNBR2',POSNBR_stats[1]),
		('EV_POSNER1',POSNER_stats[0]),('EV_POSNER2',POSNER_stats[1]),
		('EV_RECOG1',RECOG_stats[0]),('EV_RECOG2',RECOG_stats[1]),
		('EV_RECOG3',RECOG_stats[2]),('EV_RECOG4',RECOG_stats[3]),
		('EV_SENT1',SENT_stats[0]),('EV_SENT2',SENT_stats[1]),
		('EV_SOCIAL1',SOCIAL_stats[0]),('EV_SOCIAL2',SOCIAL_stats[1]),
		('EV_WM1',WM_stats[0]),('EV_WM2',WM_stats[1]),('EV_WM3',WM_stats[2]),('EV_WM4',WM_stats[3])])
		
		
	task_length = dict	([('EV_GAMBBR1',3),('EV_GAMBBR2',3),('EV_GAMBER1',3),('EV_GAMBER2',3),
			('EV_HAMMER1',4),('EV_HAMMER2',4),
			('EV_IAPS1',2),('EV_IAPS2',2),
			('EV_POSNBR1',4),('EV_POSNBR2',4),('EV_POSNER1',4),('EV_POSNER2',4),
			('EV_RECOG1',13),('EV_RECOG2',13),('EV_RECOG3',13),('EV_RECOG4',13),
			('EV_SENT1',8),('EV_SENT2',8),
			('EV_SOCIAL1',5),('EV_SOCIAL2',5),
			('EV_WM1',16),('EV_WM2',16),('EV_WM3',16),('EV_WM4',16)])
			
	#accepts EV directory
	directory = sys.argv[1]
	#map directory
	dirList = os.listdir(directory)
	#generate empty text file
	behavioral_data = open(directory + '/Behavioral_Stats.txt','w')
	#write out header line with all labels
	behavioral_data.write(headline_string[1:]+"\n")
	#iterate through EV directory & collect stats
	for session in dirList:
		#map EV directories starting with CP
		if session[:2] == "CP":
			#get EV directories
			EV_DIR = os.listdir(directory+"/"+session)
			#print EV_DIR
			
			sessionID = session
			
			print ('')
			print ("SessionID is: " + sessionID)
			print ("==============")
			
			all_tasks = task_pairs.keys()
			
			#iterate through tasks
			for task in all_tasks:
				#open EV directories only
				if task[:2] == "EV":
					
					try:
						curr_task = open(directory+session+'/'+task+"/Stats.txt", 'r')
						print ("Opened " + str(directory+session+'/'+task+"/Stats.txt"))
						#Grab relevant stats and save to lists
						task_data = curr_task.readlines()
						
						if task == "EV_BIOMOT" or task == "EV_BIOMOT1" or task == "EV_BIOMOT2" or task == "EV_MOTOR":
							continue
							
						else:
							task_pairs[task] = []
							for line in task_data:
								if line[0] != '=':
									line = line.split(":")
									line = line[1].rstrip()
									task_pairs[task].append(line)
							
					except:
						#look up failues in the dictionary
						print (str(task) + ' not conducted in session: ' + str(session))
						task_pairs[task] = []
						if len(task_pairs[task]) == 0:
							for i in range(task_length[task]):
								task_pairs[task].append('-999')			
						
							
			#Generate final session line
			varr_list = [task_pairs['EV_GAMBBR1'], task_pairs['EV_GAMBBR2'],
						task_pairs['EV_GAMBER1'], task_pairs['EV_GAMBER2'],
						task_pairs['EV_HAMMER1'], task_pairs['EV_HAMMER2'],
						task_pairs['EV_IAPS1'], task_pairs['EV_IAPS2'],
						task_pairs['EV_POSNBR1'], task_pairs['EV_POSNBR2'],
						task_pairs['EV_POSNER1'], task_pairs['EV_POSNER2'],
						task_pairs['EV_RECOG1'], task_pairs['EV_RECOG2'],
						task_pairs['EV_RECOG3'], task_pairs['EV_RECOG4'],
						task_pairs['EV_SENT1'], task_pairs['EV_SENT2'],
						task_pairs['EV_SOCIAL1'], task_pairs['EV_SOCIAL2'],
						task_pairs['EV_WM1'], task_pairs['EV_WM2'],
						task_pairs['EV_WM3'], task_pairs['EV_WM4']]
						
			#Write out session data
			session_line.append(sessionID)
	
			for varr in varr_list: #all task runs
				if varr != []:
					for i in range(len(varr)): #number of stats recorded per run
						session_line.append(varr[i])
			
			#print session_line
			print ("***********")
			print ("Wrote " + str(len(session_line)) + " of " + str(len(headline)) + " fields to Behavioral_Stats.txt")
			#create csv string from sesion_line
			for item in session_line:
				session_string = session_string + "\t" + str(item)
				
			behavioral_data.write(session_string[1:]+"\n")
			session_line = []
			session_string = ''
			GAMBBR_stats = [ [], [] ]
			GAMBER_stats = [ [], [] ]
			HAMMER_stats = [ [], [] ]
			IAPS_stats = [ [], [] ]
			POSNBR_stats = [ [], [] ]
			POSNER_stats = [ [], [] ]
			RECOG_stats = [ [], [], [], [] ]	
			SENT_stats = [ [], [] ]
			WM_stats = [ [], [], [], [] ]
			SOCIAL_stats = [ [], [] ]
	
	
if __name__ == "__main__":
	main()