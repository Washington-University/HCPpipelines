import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("MOTOR") != -1 or openfile.find("Motor") != -1:
		#attempt to open for reading
		tabfile = open(openfile, 'r')
		#get the length of the first line to establish # of columns
		num_columns = tabfile.readline()
		#split by tabs to sort into a list
		num_columns = num_columns.split("\t")
		#len of the list is the number of columns
		num_columns_len = len(num_columns)
		#save all remaining data to a list
		data = tabfile.readlines()
		
		#get relevant columns
		Proc_Block = [] #14 #index starts at 0
		Proc_Trial = [] #22
		LHC_Onset = [] #28
		LFC_Onset = [] #62
		RHC_Onset = [] #65
		RFC_Onset = [] #37
		TC_Onset = [] #43
		CL_Onset = [] #31
		CR_Onset = [] #40
		CC_Onset = [] #46
		Sync_Onset = []
		Sync_Val = False
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "Procedure[Trial]":
				PT_Index = i
			elif num_columns[i] == "LeftHandCue.OnsetTime":
				LHC_Index = i
			elif num_columns[i] == "LeftFootCue.OnsetTime":
				LFC_Index = i
			elif num_columns[i] == "RightHandCue.OnsetTime":
				RHC_Index = i
			elif num_columns[i] == "RightFootCue.OnsetTime":
				RFC_Index = i
			elif num_columns[i] == "TongueCue.OnsetTime":
				TC_Index = i
			elif num_columns[i] == "CrossLeft.OnsetTime":
				CL_Index = i
			elif num_columns[i] == "CrossRight.OnsetTime":
				CR_Index = i
			elif num_columns[i] == "CrossCenter.OnsetTime":
				CC_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime" or num_columns[i] == "CountDownSlide.OnsetTime":
				SO_Index = i
				
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/lf.txt','w')
		EV2 = open(str(sys.argv[2]) + '/lh.txt','w')
		EV3 = open(str(sys.argv[2]) + '/rf.txt','w')
		EV4 = open(str(sys.argv[2]) + '/rh.txt','w')
		EV5 = open(str(sys.argv[2]) + '/t.txt','w')
		EV6 = open(str(sys.argv[2]) + '/cue.txt','w')
		
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
	
	
		for i in range(len(data)): #80
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == PT_Index:
					Proc_Trial.append(tempdata[j])
				elif j == LHC_Index:
					LHC_Onset.append(tempdata[j])
				elif j == LFC_Index:
					LFC_Onset.append(tempdata[j])
				elif j == RHC_Index:
					RHC_Onset.append(tempdata[j])	
				elif j == RFC_Index:
					RFC_Onset.append(tempdata[j])
				elif j == TC_Index:
					TC_Onset.append(tempdata[j])
				elif j == CL_Index:
					CL_Onset.append(tempdata[j])
				elif j == CR_Index:
					CR_Onset.append(tempdata[j])
				elif j == CC_Index:
					CC_Onset.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
				
				
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		#iterate through all blocks
		for i in range(len(Proc_Block)):
		
			if Proc_Block[i] == "SyncUp" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
		
			#check to see if you're in the task
			if Proc_Block[i] == "MainTaskPROC":
				#check to see what trial you're in
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
				
					#check what cue your first cue is and save it's onset as t0
					if Proc_Trial[First_Index] == "LeftHandCueProcedure":
						First_Onset = int(LHC_Onset[i])/1000.0
					elif Proc_Trial[First_Index] == "RightHandCuePROC":
						First_Onset = int(FHC_Onset[i])/1000.0
					elif Proc_Trial[First_Index] == "LeftFootCuePROC":
						First_Onset = int(LFC_Onset[i])/1000.0
					elif Proc_Trial[First_Index] == "RightFoottCuePROC":
						First_Onset = int(RFC_Onset[i])/1000.0
					else:
						First_Onset = int(TC_Onset[i])/1000.0
					
					print "First Onset set to " + str(First_Onset)
					
			
				#if you're in a cue
				if Proc_Trial[i] == "LeftHandCueProcedure" and Proc_Trial[i-1] != "LeftHandCueProcedure":
					#convert ms to seconds
					LHC_Onset_sec = int(LHC_Onset[i])/1000.0 - Sync_Val
					#write output to EV file
					EV6.write(str(LHC_Onset_sec) + "	" + "3" + "	" + "1"+"\n")
				
				elif Proc_Trial[i] == "RightHandCuePROC" and Proc_Trial[i-1] != "RightHandCuePROC":
					#convert ms to seconds
					RHC_Onset_sec = int(RHC_Onset[i])/1000.0 - Sync_Val
					#write output to EV file
					EV6.write(str(RHC_Onset_sec) + "	" + "3" + "	" + "1"+"\n")
				
				elif Proc_Trial[i] == "LeftFootCuePROC" and Proc_Trial[i-1] != "LeftFootCuePROC":
					#convert ms to seconds
					LFC_Onset_sec = int(LFC_Onset[i])/1000.0 - Sync_Val
					#write output to EV file
					EV6.write(str(LFC_Onset_sec) + "	" + "3" + "	" + "1"+"\n")
								
				elif Proc_Trial[i] == "RightFoottCuePROC" and Proc_Trial[i-1] != "RightFoottCuePROC":
					#convert ms to seconds
					RFC_Onset_sec = int(RFC_Onset[i])/1000.0 - Sync_Val
					#write output to EV file
					EV6.write(str(RFC_Onset_sec) + "	" + "3" + "	" + "1"+"\n")
				
				elif Proc_Trial[i] == "TongueCuePROC" and Proc_Trial[i-1] != "TongueCuePROC":
					#convert ms to seconds
					TC_Onset_sec = int(TC_Onset[i])/1000.0 - Sync_Val
					#write output to EV file
					EV6.write(str(TC_Onset_sec) + "	" + "3" + "	" + "1"+"\n")
				
				#if you're in a Cross presentation
				if Proc_Trial[i] == "CrossCenterPROC" and Proc_Trial[i-1] == "TongueCuePROC":
					#convert ms to seconds
					CC_Onset_sec = int(CC_Onset[i])/1000.0 - Sync_Val
					#you're in a center cross PROC so it has to be tongue - write to EV
					EV5.write(str(CC_Onset_sec) + "	" + "12" + "	" + "1"+"\n")
			
			
				if Proc_Trial[i] == "CrossLeftPROC":
					#don't know if you're in hand or foot - check
					if Proc_Trial[i-1] == "LeftFootCuePROC":
						#convert from ms to seconds
						CL_Onset_sec = int(CL_Onset[i])/1000.0 - Sync_Val
						#you're in left foot
						EV1.write(str(CL_Onset_sec) + "	" + "12" + "	" + "1"+"\n")
					
					elif Proc_Trial[i-1] == "LeftHandCueProcedure":
						#convert from ms to seconds
						CL_Onset_sec = int(CL_Onset[i])/1000.0 - Sync_Val
						#you're in left hand
						EV2.write(str(CL_Onset_sec) + "	" + "12" + "	" + "1"+"\n")
					
					
				if Proc_Trial[i] == "CrossRightPROC":
					#don't know if you're in hand or foot - check
					if Proc_Trial[i-1] == "RightFoottCuePROC":
						#convert from ms to seconds
						CR_Onset_sec = int(CR_Onset[i])/1000.0 - Sync_Val
						#you're in right foot
						EV3.write(str(CR_Onset_sec) + "	" + "12" + "	" + "1"+"\n")
					
					elif Proc_Trial[i-1] == "RightHandCuePROC":
						#convert from ms to seconds
						CR_Onset_sec = int(CR_Onset[i])/1000.0 - Sync_Val
						#you're in right hand
						EV4.write(str(CR_Onset_sec) + "	" + "12" + "	" + "1"+"\n")
					
					
				#manually advance i to ensure no multiples are taken - accounted for by duration
			
	
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
		EV5.close()
		EV6.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")
		
if __name__ == "__main__":
	main()