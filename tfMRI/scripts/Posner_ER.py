import sys, os

def main():
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("POS_ER") != -1:
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
	
		#iterate data and sort it into columns - saving columns of interest
		Proc_Block = [] #column #21
		Proc_Trial = [] #column #29
		Validity = [] #column #39
		Cue_Image = [] #column #40
		Target_Image = [] #column #42
		Cue_Onset = [] #column #48
		Target_Onset = [] #column #54
		Response_Onset = [] #column #57
		Stim_RT = []
		Resp_ACC = [] #column 60
		Sync_Onset = []
		Sync_Val = False
		ACC = [ [], [] ]
		RT = [ [], [] ]
			
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "Procedure[Trial]":
				PT_Index = i
			elif num_columns[i] == "Validity":
				Val_Index = i
			elif num_columns[i] == "CueImage":
				Cue_Index = i
			elif num_columns[i] == "TargetImage":
				Target_Index = i
			elif num_columns[i] == "Cue.OnsetTime":
				CueOnset_Index = i
			elif num_columns[i] == "Target.OnsetTime":
				TargetOnset_Index = i
			elif num_columns[i] == "Response.OnsetTime":
				ResponseOnset_Index = i
			elif num_columns[i] == "Response.ACC" or num_columns[i] == "Target.ACC":
				RespACC_Index= i
			elif num_columns[i] == "SyncSlide.OnsetTime" or num_columns[i] == "CountDownSlide.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "Stim.RT" or num_columns[i] == "Target.RT" or num_columns[i] == "Response.RT":
				RT_Index = i
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/cue.txt','w')
		EV2 = open(str(sys.argv[2]) + '/inv.txt','w')
		EV3 = open(str(sys.argv[2]) + '/val.txt','w')
		EV4 = open(str(sys.argv[2]) + '/val_err.txt', 'w')
		EV5 = open(str(sys.argv[2]) + '/inv_err.txt', 'w')
		EV6 = open(str(sys.argv[2]) + '/val_cor.txt','w')
		EV7 = open(str(sys.argv[2]) + '/inv_cor.txt','w')
	
		EV8 = open(str(sys.argv[2]) + '/cue_rt.txt','w')
		EV9 = open(str(sys.argv[2]) + '/inv_rt.txt','w')
		EV10 = open(str(sys.argv[2]) + '/val_rt.txt','w')
		EV11 = open(str(sys.argv[2]) + '/val_err_rt.txt', 'w')
		EV12 = open(str(sys.argv[2]) + '/inv_err_rt.txt', 'w')
		EV13 = open(str(sys.argv[2]) + '/val_cor_rt.txt','w')
		EV14 = open(str(sys.argv[2]) + '/inv_cor_rt.txt','w')
	
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
		
	
		for i in range(len(data)): #80
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == PT_Index:
					Proc_Trial.append(tempdata[j])
				elif j == Val_Index:
					Validity.append(tempdata[j])
				elif j == Cue_Index:
					Cue_Image.append(tempdata[j])
				elif j == Target_Index:
					Target_Image.append(tempdata[j])	
				elif j == CueOnset_Index:
					Cue_Onset.append(tempdata[j])
				elif j == TargetOnset_Index:
					Target_Onset.append(tempdata[j])
				elif j == ResponseOnset_Index:
					Response_Onset.append(tempdata[j])
				elif j == RespACC_Index:
					Resp_ACC.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					Stim_RT.append(tempdata[j])
								
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		#iterate through all blocks
		for i in range(len(Proc_Block)):
		
			if Proc_Block[i] == "SyncUp" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
			
			#check to see if you're in the task
			if Proc_Trial[i] == "TrialRunPROC":
				#check to see what trial you're in
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
				
					#First onset is simply the first cue presented
					First_Onset = int(Cue_Onset[First_Index])/1000.00
					print "First onset set to: " + str(First_Onset)
				
				#if you're in a valid trial
				Target_Onset_sec = int(Cue_Onset[i])/1000.00 - Sync_Val
				Stim_RT_Sec = int(Stim_RT[i])/1000.00
			
				if Validity[i] == "Valid":
					#convert ms to seconds
					if Cue_Image[i][3:7] == "Left":
						#check if errors were made
						if Resp_ACC[i] == "1":
							#write output to EV file
							EV3.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV6.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV10.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV13.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
						else:
							EV3.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV4.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV10.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV11.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
												
					elif Cue_Image[i][3:8] == "Right":
						#check if errors were made
						if Resp_ACC[i] == "1":
							#write out to EV file
							EV3.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV6.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV10.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV13.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
						else:
							EV3.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV4.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV10.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV11.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
						
				elif Validity[i] == "Invalid":
					if Cue_Image[i][3:7] == "Left":
						#check if errors were made
						if Resp_ACC[i] == "1":
							#write out to EV file
							EV2.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV7.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV9.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV14.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
						else:
							EV2.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV5.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV9.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV12.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
					
					elif Cue_Image[i][3:8] == "Right":
						#check if errors were made
						if Resp_ACC[i] == "1":
							#write to EV
							EV2.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV7.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV9.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV14.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
						else:
							EV2.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
							EV5.write(str(Target_Onset_sec) + "	" + "2.5" + "	" + "1"+"\n")
						
							EV9.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
							EV12.write(str(Target_Onset_sec)+ "	" + "2.5" + "	" + str(Stim_RT_Sec)+"\n")
		
				#unconditionally write out all of the cues
				Cue_Onset_sec = int(Cue_Onset[i])/1000.00 - Sync_Val
				EV1.write(str(Cue_Onset_sec) + "	" + "1" + "	" + "1"+"\n")
				EV8.write(str(Cue_Onset_sec) + "	" + "1" + "	" + str(Stim_RT_Sec)+"\n")
			
			if Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Valid":
				ACC[0].append(int(Resp_ACC[i]))
			elif Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Invalid":
				ACC[1].append(int(Resp_ACC[i]))

			if Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Valid" and Resp_ACC[i] == "1":
				RT[0].append(float(Stim_RT[i]))
			elif Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Invalid" and Resp_ACC[i] == "1":
				RT[1].append(float(Stim_RT[i]))
			
		#Compute stats
		for i in range(len(ACC)):
			total = len(ACC[i])
			if total != 0:
				ACC[i] = (sum(ACC[i])/float(total))
			else:
				print ("WARNING ZeroDivisionError")
				ACC[i] = -555

		for i in range(len(RT)):
			total = len(RT[i])
			if total != 0:
				RT[i] = (sum(RT[i])/float(total))
			else:
				print ("WARNING ZeroDivisionError")
				RT[i] = -555

		Stats.write("Accuracy on invalid trials: " + str(ACC[1])+"\n")
		Stats.write("Accuracy on valid trials: " + str(ACC[0])+"\n")
		Stats.write("=============="+"\n")
		Stats.write("Median RT to correct invalid trials: " + str(RT[1])+"\n")
		Stats.write("Median RT to correct valid trials: " + str(RT[0])+"\n")		
			
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
		EV5.close()
		EV6.close()	
		EV7.close()
	
		EV8.close()
		EV9.close()
		EV10.close()
		EV11.close()
		EV12.close()
		EV13.close()	
		EV14.close()
	
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")
	
if __name__ == "__main__":
	main()