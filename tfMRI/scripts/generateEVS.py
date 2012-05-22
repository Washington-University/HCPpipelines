import sys, os
import subprocess

def main():
	#directory is edat directory
	directory = sys.argv[1]
	#create a list of all files in edat directory
	dirList = os.listdir(directory)
	#output is evs directory
	outputdir = sys.argv[2]
	cmd = 'mkdir -p ' + str(outputdir)
	os.system(cmd)
	
	#initialize data holders
	runslist = []
	IAPS = []
	WM = []
	RECOG = []
	SENT = []
	SOCIAL_COG = []
	
	#create a dictionary of tasks and associated file lengths
	edat_length = dict	([('BIOMOTION_Minn_run',29),('BIOMOTION_run1+practice',32),('BIOMOTION_run2+practice',32),
			('GAMB_BLOCKED-run',77),('GAMB_BLOCKED_run',77),('GAMB_ER_run',69),('GAMB-ER_run',69),
			('HAMMER_run',72),('Hammer_Task',78),('Hammer_Task-10022',84),
			('IAPS_run',235),
			('Motor_Task_Minn',280),('MOTOR_Minn_run',250),
			('POS_BLOCKED_run',95),('POS_ER_run',81),
			('REC_run1-',101),('REC_run2-',101),('REC_run3-',101),('REC_run4-',101),
			('REC_run',53),
			('SENT_Minn_run',53),
			('SOCIAL_Minn_run',25),('SocialTask_Minn_run',27),
			('WM_Minn_run',97),('WM-Minn_run',97)])
	
	alledats = edat_length.keys()
		
	#items are files in edat directory
	for item in dirList:
		#check for _TAB.txt files
		if item[-8:] == "_TAB.txt":
			#check for practice items identified by _practice, +practice are valid trials	
			if item.find("_practice") != -1:
				print ("Skipping Practice: " + str(item))
			else:
				print(item)
				#check edat file length
				openfile = str(directory)+str(item)
				#attempt to open for reading
				tabfile = open(openfile, 'r')
				#save all data to a list, length is number of lines in the file
				data = tabfile.readlines()
				numlines = len(data)
				
				#compare numlines to expected
				for edat in alledats:
					#match possible edat name to actual edats found
					if item.find(edat) != -1:
						#edats match, check length
						if edat_length[edat] == numlines:
							#append valid trial edat to runslist
							runslist.append(item)
						else:
							#print some output for log.txt
							print ("Skipping " + item)
							print ("Edat length did not match expected")
							print ("Edat Found: " + str(numlines))
							print ("Edat Expected: " + str(edat_length[edat]))
							print ("---------------")
							
				
	print ("---------------")
			
	for item in runslist:
		print (item)
		#search match edat item to task
		if item.find("BIOMOTION") != -1:
			#match edat run to run
			if item.find("run1") != -1:
				print ("Executing Biomotion.py Run 1")
				#set cmd to task script and EV folder
				cmd = "python Biomotion.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_BIOMOT"
				#execute task and write output to log.txt
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				#set cmd to get rest onset script
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				#execute restonset script and write output to restOnset.txt
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_BIOMOT/restOnset.txt")
				print ("---------------")
				
			elif item.find("run2") != -1:
				print ("Executing Biomotion.py Run 2")
				cmd = "python Biomotion.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_BIOMOT"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_BIOMOT/restOnset.txt")
				print ("---------------")
				
			else:
				print ("Executing Biomotion.py Generic")
				cmd = "python Biomotion.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_BIOMOT"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_BIOMOT/restOnset.txt")
				print ("---------------")
			
		if item.find("GAMB_BLOCKED") != -1:
			if item.find("run1") != -1 or item.find("run3") != -1:
				print ("Executing Gambling_BR1")
				cmd = "python Gambling_BR.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_GAMBBR1"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_GAMBBR1/restOnset.txt")
				print ("---------------")
				
			elif item.find("run2") != -1 or item.find("run4") != -1:
				print ("Executing Gambling_BR2")
				cmd = "python Gambling_BR.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_GAMBBR2"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_GAMBBR2/restOnset.txt")
				print ("---------------")
				
		if item.find("Motor_") != -1 or item.find("MOTOR_") != -1:
			print ("Executing Motor")
			cmd = "python Motor.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_MOTOR"
			os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
			cmd = "python getRestOnset.py "+str(directory)+str(item)
			os.system(cmd + " > "+str(sys.argv[2])+"/EV_MOTOR/restOnset.txt")
			print ("---------------")
			
		if item.find("POS_ER") != -1:
			if item.find("run1") != -1:
				print ("Executing Posner_ER1")
				cmd = "python Posner_ER.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_POSNER1"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_POSNER1/restOnset.txt")
				print ("---------------")
				
			elif item.find("run2") != -1:
				print ("Executing Posner_ER2")
				cmd = "python Posner_ER.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_POSNER2"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_POSNER2/restOnset.txt")
				print ("---------------")
				
		if item.find("GAMB-ER") != -1 or item.find("GAMB_ER") != -1:
			if item.find("run1") != -1:
				print ("Executing GAMB-ER1")
				cmd = "python Gambling_ER.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_GAMBER1"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_GAMBER1/restOnset.txt")
				print ("---------------")
				
			elif item.find("run2") != -1:
				print ("Executing GAMB-ER2")
				cmd = "python Gambling_ER.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_GAMBER2"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_GAMBER2/restOnset.txt")
				print ("---------------")
				
		if item.find("HAMMER") != -1 or item.find("Hammer") != -1:
			if item.find("run1") != -1:
				print ("Executing Hammer1")
				cmd = "python Hammer.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_HAMMER1"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_HAMMER1/restOnset.txt")
				print ("---------------")
				
			elif item.find("run2") != -1:
				print ("Executing Hammer2")
				cmd = "python Hammer.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_HAMMER2"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_HAMMER2/restOnset.txt")
				print ("---------------")
			
			if item.find("Hammer_Task") != -1:
				print ("Executing Hammer Generic")
				cmd = "python Hammer.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_HAMMER1"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_HAMMER1/restOnset.txt")
				print ("---------------")
				
		if item.find("POS_BLOCKED") != -1:
			if item.find("run1") != -1:
				print ("Executing POSBR1")
				cmd = "python Posner_BR.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_POSNBR1"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_POSNBR1/restOnset.txt")
				print ("---------------")
				
			elif item.find("run2") != -1:
				print ("Executing POSBR2")
				cmd = "python Posner_BR.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_POSNBR2"
				os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
				cmd = "python getRestOnset.py "+str(directory)+str(item)
				os.system(cmd + " > "+str(sys.argv[2])+"/EV_POSNBR2/restOnset.txt")
				print ("---------------")
				
		#Counterbalanced tasks start here
		#Search for counter balanced task
		if item.find("SENT_") != -1:
			#append timestamp data to task list
			print ("Appending SENT Run to list")
			#set cmd to grab timestamp from edat files
			cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
			#execute cmd and write timestamp to a temporary holder
			os.system(cmd + " > tmp.txt")
			#read in holder
			fp = open('tmp.txt')
			#grab and strip the timestamp
			time = fp.readlines()[0].rstrip()
			#append the timestamp to the SENT list
			SENT.append(time)
			#clear the holder
			time = ''
			print ("---------------")
				
		if item.find("SOCIAL_") != -1 or item.find("Social") != -1:
			#append timestamp data to task list
			print ("Appending SOCIAL Run to list")
			cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
			os.system(cmd + " > tmp.txt")
			fp = open('tmp.txt')
			time = fp.readlines()[0].rstrip()
			SOCIAL_COG.append(time)
			time = ''
			print ("---------------")
	
		if item.find("REC_") != -1:
			#append timestamp data to task list
			print ("Appending RECOG Run to list")
			cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
			os.system(cmd + " > tmp.txt")
			fp = open('tmp.txt')
			time = fp.readlines()[0].rstrip()
			RECOG.append(time)
			time = ''
			print ("---------------")
			
		if item.find("WM_") != -1 or item.find("WM-") != -1:
			#append timestamp data to task list
			print ("Appending WM Run to list")
			cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
			os.system(cmd + " > tmp.txt")
			fp = open('tmp.txt')
			time = fp.readlines()[0].rstrip()
			WM.append(time)
			time = ''
			print ("---------------")
			
		if item.find("EIAPS") != -1 or item.find("IAPS") != -1:
			#append timestamp data to task list
			print ("Appending IAPS Run to list")
			cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
			os.system(cmd + " > tmp.txt")
			fp = open('tmp.txt')
			time = fp.readlines()[0].rstrip()
			IAPS.append(time)
			time = ''
			print ("---------------")
						
	#sort counter-balanced runs by timestamp
	IAPS.sort()
	WM.sort()
	RECOG.sort()
	SENT.sort()
	SOCIAL_COG.sort()
	
	#Execute IAPS
	#match timestamp with filename
	#reverse the sorted order to pop off the lowest timestamp first
	IAPS.reverse()
	#check that the list is not empty
	if len(IAPS) != 0:
		#iterate exactly the number of task blocks expected (prevents erroneous EV_folders)
		for i in range(1,3):
			#check the list is not empty
			if len(IAPS) != 0:
				#since its not empty - pop an item off
				timestamp = IAPS.pop()
			
			print ("IAPS Run #"+str(i))
			print (timestamp)
			for item in runslist:
				#set cmd to get the timestamp again
				cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
				#write it out to tmp file
				os.system(cmd + " > tmp.txt")
				fp = open('tmp.txt')
				#read it in and strip it
				time = fp.readlines()[0].rstrip()
				
				#if the new timestamp matches the one in the list - the edat matches
				if timestamp == time:
					print (item)
					print ("Executing IAPS" + str(i))
					#set cmd to execute task script
					cmd = "python IAPS.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_IAPS"+str(i)
					#execute task script and write out results to log.txt
					os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
					#set cmd to restOnset script
					cmd = "python getRestOnset.py "+str(directory)+str(item)
					#execute and write out output to restOnset
					os.system(cmd + " > "+str(sys.argv[2])+"/EV_IAPS"+str(i)+"/restOnset.txt")
					print ("---------------")
	else:
		print ("IAPS had no trials in " + str(directory))
		print ("---------------")
		
		
	#Execute SENT
	#match timestamp with filename
	SENT.reverse()
	if len(SENT) != 0:
		for i in range(1,3):
			if len(SENT) != 0:
				timestamp = SENT.pop()
			print ("SENT Run #"+str(i))
			print (timestamp)
			for item in runslist:
				#if the timestamp matches - run the file
				cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
				os.system(cmd + " > tmp.txt")
				fp = open('tmp.txt')
				time = fp.readlines()[0].rstrip()
			
				if timestamp == time:
					print (item)
					if item.find('run4') != -1:
						#only execute run 4 for certain subjects after a script change
						if item.find('10087')!=-1 or item.find('10040')!=-1 or item.find('10068')!=-1:
							cmd = "python Sentence.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_SENT" + str(i)
							os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
							cmd = "python getRestOnset.py "+str(directory)+str(item)
							os.system(cmd + " > "+str(sys.argv[2])+"/EV_SENT"+str(i)+"/restOnset.txt")
							time = ''
							print ("---------------")
						else:
							#everyone else does this for run 4
							cmd = "python Sentences_run4.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_SENT" + str(i)
							os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
							cmd = "python getRestOnset.py "+str(directory)+str(item)
							os.system(cmd + " > "+str(sys.argv[2])+"/EV_SENT"+str(i)+"/restOnset.txt")
							time = ''
							print ("---------------")
					else:
						#everyone else does this for runs 1-3
						cmd = "python Sentence.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_SENT" + str(i)
						os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
						cmd = "python getRestOnset.py "+str(directory)+str(item)
						os.system(cmd + " > "+str(sys.argv[2])+"/EV_SENT"+str(i)+"/restOnset.txt")
						time = ''
						print ("---------------")
	else:
		print ("Sentences had no trials in " + str(directory))
		print ("---------------")
		
						
	#Execute SOCIAL_COG
	#match timestamp with filename
	SOCIAL_COG.reverse()
	if len(SOCIAL_COG) != 0:
		for i in range(1,3):
			if len(SOCIAL_COG) != 0:
				timestamp = SOCIAL_COG.pop()
			print ("SOCIAL COG Run #"+str(i))
			print (timestamp)
			for item in runslist:
				#if the timestamp matches - run the file
				cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
				os.system(cmd + " > tmp.txt")
				fp = open('tmp.txt')
				time = fp.readlines()[0].rstrip()
			
				if timestamp == time:
					print (item)
					cmd = "python Social.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_SOCIAL" + str(i)
					os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
					cmd = "python getRestOnset.py "+str(directory)+str(item)
					os.system(cmd + " > "+str(sys.argv[2])+"/EV_SOCIAL"+str(i)+"/restOnset.txt")
					time = ''
					print ("---------------")
	else:
		print ("Social Cog had no trials in " + str(directory))
		print ("---------------")
		
	
	#Execute WM
	#match timestamp with filename
	WM.reverse()
	if len(WM) != 0:
		maxtrials = len(WM)
		totalexecutes = 0
		for i in range(1,5):
			if len(WM) != 0:
				timestamp = WM.pop()
			print ("WM Run #"+str(i))
			print (timestamp)
			for item in runslist:
				#if the timestamp matches - run the file
				cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
				os.system(cmd + " > tmp.txt")
				fp = open('tmp.txt')
				time = fp.readlines()[0].rstrip()
						
				if timestamp == time and totalexecutes < maxtrials:
					#if the runcount is 1
					if i == 1 or i == 3:
						#run should be 1,3,5,7 (first and third runs can be any of these four, 1&3 or 5&7)
						if item.find('run1')!=-1 or item.find('run5')!=-1 or item.find('run3')!=-1 or item.find('run7')!=-1:
							print (item)
							print ("Executing WM EV Directory #" + str(i))
							cmd = "python WM.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_WM" + str(i)
							os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
							cmd = "python getRestOnset.py "+str(directory)+str(item)
							os.system(cmd + " > "+str(sys.argv[2])+"/EV_WM"+str(i)+"/restOnset.txt")
							time = ''
							totalexecutes = totalexecutes + 1
							print ("---------------")
						else:
							print ("EDAT not found. Advancing.")
							print ("---------------")
						
					elif i == 2 or i == 4:
						#run should be 6,8,2,4 (second and fourth runs can be any of these four, 2&4 or 6&8)
						if item.find('run6')!=-1 or item.find('run8')!=-1 or item.find('run2')!=-1 or item.find('run4')!=-1:
							print (item)
							print ("Executing WM EV Directory #" + str(i))
							cmd = "python WM.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_WM" + str(i)
							os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
							cmd = "python getRestOnset.py "+str(directory)+str(item)
							os.system(cmd + " > "+str(sys.argv[2])+"/EV_WM"+str(i)+"/restOnset.txt")
							time = ''
							totalexecutes = totalexecutes + 1
							print ("---------------")
						else:
							print ("EDAT not found. Advancing.")
							print ("---------------")
				elif timestamp == time and totalexecutes >= maxtrials:
					print ("---------------")
	else:
		print ("WM had no trials in " + str(directory))
		print ("---------------")
		
		
	#Executing RECOG
	#match timestamp with filename
	RECOG.reverse()
	if len(RECOG) != 0:
		maxtrials = len(RECOG)
		totalexecutes = 0
		for i in range(1,5):
			if len(RECOG) != 0:
				timestamp = RECOG.pop()
			
			print ("RECOG Run #"+str(i))
			print (timestamp)
			for item in runslist:
				#if the timestamp matches - run the file
				cmd = "cat " + str(directory) + str(item) + " | grep ':' | awk '{print $3}' | tr ':' '.' | sort -u"
				os.system(cmd + " > tmp.txt")
				fp = open('tmp.txt')
				time = fp.readlines()[0].rstrip()
			
				if timestamp == time and totalexecutes < maxtrials:
						#if the runcount is 1 or 3
					if i == 1 or i == 3:
						#run should be 1,3,5,7
						if item.find('run1')!=-1 or item.find('run5')!=-1 or item.find('run3')!=-1 or item.find('run7')!=-1:
							print (item)
							print ("Executing Recog EV Directory #" + str(i))
							cmd = "python Recog.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_RECOG" + str(i)
							os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
							cmd = "python getRestOnset.py "+str(directory)+str(item)
							os.system(cmd + " > "+str(sys.argv[2])+"/EV_RECOG"+str(i)+"/restOnset.txt")
							time = ''
							totalexecutes = totalexecutes + 1
							print ("---------------")
						else:
							print ("EDAT not found. Advancing.")
							print ("---------------")
					
					elif i == 2 or i == 4:
						#run should be 6,8,2,4
						if item.find('run6')!=-1 or item.find('run8')!=-1 or item.find('run2')!=-1 or item.find('run4')!=-1:
							print (item)
							print ("Executing Recog EV Directory #" + str(i))
							cmd = ("python Recog.py "+str(directory)+str(item)+" "+str(sys.argv[2])+"/EV_RECOG" + str(i))
							os.system(cmd + " > "+str(sys.argv[2])+"/log.txt")
							cmd = "python getRestOnset.py "+str(directory)+str(item)
							os.system(cmd + " > "+str(sys.argv[2])+"/EV_RECOG"+str(i)+"/restOnset.txt")
							time = ''
							totalexecutes = totalexecutes + 1
							print ("---------------")
						else:
							print ("EDAT not found. Advancing.")
							print ("---------------")
				elif timestamp == time and totalexecutes >= maxtrials:
					print ("---------------")
					
	else:
		print ("Recog had no trials in " + str(directory))
		print ("---------------")
		
	cmd = ("python EV_Check.py "+str(sys.argv[2]))
	os.system(cmd)
		
			
if __name__ == "__main__":
	main()