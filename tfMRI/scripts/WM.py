import sys, os, math

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("WM")!= -1:
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
		
		Proc_Block = []
		BlockType = []
		StimType = []
		Stim_Onset = []
		Stim_ACC = []
		Manual_Stim_ACC = []
		Stim_RT = []
		Corr_Resp = []
		Stim_Resp = []
		Cue2Back_Onset = []
		CueTarget_Onset = []
		CueTarget_Onset = []
		TargetType = []
		ImageName = []
		Sync_Onset = []
		Sync_Val = False
		RT_Zero_Median = [ [], [], [], [] ]
		RT_Two_Median = [ [], [], [], [] ]
		ACC_Zero_Median = [ [], [], [], [] ]
		ACC_Two_Median = [ [], [], [], [] ]
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
			 	PB_Index = i
			elif num_columns[i] == "BlockType":
				BT_Index = i
			elif num_columns[i] == "StimType":
				ST_Index = i
			elif num_columns[i] == "Stim.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "Stim.ACC":
				ACC_Index = i
			elif num_columns[i] == "Cue2Back.OnsetTime":
				C2B_Index = i
			elif num_columns[i] == "CueTarget.OnsetTime":
				C0B_Index = i
			elif num_columns[i] == "TargetType":
				TT_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SYO_Index = i
			elif num_columns[i] == "Stim.RT":
				RT_Index = i
			elif num_columns[i] == "CorrectResponse" or num_columns[i] == "Stim.CRESP":
				CR_Index = i
			elif num_columns[i] == "Stim.Resp" or num_columns[i] == "Stim.RESP":
				SR_Index = i
			elif num_columns[i] == "Stimulus[Block]":
				IN_Index = i
			
	
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/0bk_cor.txt','w')
		EV2 = open(str(sys.argv[2]) + '/2bk_cor.txt','w')
		EV3 = open(str(sys.argv[2]) + '/0bk_tools.txt','w')
		EV4 = open(str(sys.argv[2]) + '/0bk_faces.txt','w')
		EV5 = open(str(sys.argv[2]) + '/0bk_places.txt','w')
		EV6 = open(str(sys.argv[2]) + '/0bk_body.txt','w')
		EV7 = open(str(sys.argv[2]) + '/2bk_tools.txt','w')
		EV8 = open(str(sys.argv[2]) + '/2bk_faces.txt','w')
		EV9 = open(str(sys.argv[2]) + '/2bk_places.txt','w')
		EV10 = open(str(sys.argv[2]) + '/2bk_body.txt','w')
		EV11 = open(str(sys.argv[2]) + '/0bk_err.txt','w')
		EV12 = open(str(sys.argv[2]) + '/2bk_err.txt','w')
		EV13 = open(str(sys.argv[2]) + '/0bk_nlr.txt','w')
		EV14 = open(str(sys.argv[2]) + '/2bk_nlr.txt','w')
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
	
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == BT_Index:
					BlockType.append(tempdata[j])
				elif j == ST_Index:
					StimType.append(tempdata[j])
				elif j == SO_Index:
					Stim_Onset.append(tempdata[j])
				elif j == ACC_Index:
					Stim_ACC.append(tempdata[j])
				elif j == C2B_Index:
					Cue2Back_Onset.append(tempdata[j])
				elif j == C0B_Index:
					CueTarget_Onset.append(tempdata[j])
				elif j == TT_Index:
					TargetType.append(tempdata[j])
				elif j == SYO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					Stim_RT.append(tempdata[j])
				elif j == CR_Index:
					Corr_Resp.append(tempdata[j])
				elif j == SR_Index:
					Stim_Resp.append(tempdata[j])
				elif j == IN_Index:
					ImageName.append(tempdata[j])
					
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		First_Onset = 0000
		
		#copy Stim_ACC to Manual_Stim_ACC
		Manual_Stim_ACC = Stim_ACC
		
		#iterate through all blocks
		for i in range(len(Proc_Block)):
		
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
			#check if in trial
			if Proc_Block[i] == "TrialsPROC" and Proc_Block[i-2] == "TRSyncPROC":
				#you are in a trial
				#set first index
				First_Index = i
				if Proc_Block[First_Index] == "Cue2BackPROC":
					First_Onset = Cue2Back_Onset[i]
				elif Proc_Block[First_Index] == "Cue0BackPROC":
					First_Onset = CueTarget_Onset[i]
				elif Proc_Block[First_Index] == "TrialsPROC":
					First_Onset = Stim_Onset[i]
				print("First Onset set to: " + str(int(First_Onset)/1000.0))
					
			if Proc_Block[i] == "TrialsPROC":
				#set onset time
				if Cue2Back_Onset[i-1] != '' and Proc_Block[i-1] != "TrialsPROC":
					Onset_Time_Sec = int(Cue2Back_Onset[i-1])/1000.0 - Sync_Val
				elif CueTarget_Onset[i-1] != '' and Proc_Block[i-1] != "TrialsPROC":
					Onset_Time_Sec = int(CueTarget_Onset[i-1])/1000.0 - Sync_Val
				
				#check blocktype
				if BlockType[i] == "0-Back":					
					#check trialtype
					if StimType[i] == "Tools":
						if Proc_Block[i-1] != "TrialsPROC":
							EV3.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Zero_Median[2].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Zero_Median[2].append(float(Stim_RT[i]))
					
					elif StimType[i] == "Face":
						if Proc_Block[i-1] != "TrialsPROC":
							EV4.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Zero_Median[0].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Zero_Median[0].append(float(Stim_RT[i]))
					
					elif StimType[i] == "Place":
						if Proc_Block[i-1] != "TrialsPROC":
							EV5.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")	
						ACC_Zero_Median[1].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Zero_Median[1].append(float(Stim_RT[i]))
					
					elif StimType[i] == "Body":
						if Proc_Block[i-1] != "TrialsPROC":
							EV6.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Zero_Median[3].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Zero_Median[3].append(float(Stim_RT[i]))
					
				elif BlockType[i] == "2-Back":
					#correct stats for all 2-back blocks
					#if the image matches two images previous
					if ImageName[i] == ImageName[i-2]:
						#if the response given was "target"
						if Stim_Resp[i] == "b":
							#accuracy is actually 1
							Stim_ACC[i] = "1"
						else:
							#it was incorrect
							Stim_ACC[i] = "0"
							
					#check trialtype
					if StimType[i] == "Tools":
						if Proc_Block[i-1] != "TrialsPROC":
							EV7.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Two_Median[2].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Two_Median[2].append(float(Stim_RT[i]))
					
					elif StimType[i] == "Face":
						if Proc_Block[i-1] != "TrialsPROC":
							EV8.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Two_Median[0].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Two_Median[0].append(float(Stim_RT[i]))
						
					elif StimType[i] == "Place":
						if Proc_Block[i-1] != "TrialsPROC":
							EV9.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Two_Median[1].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Two_Median[1].append(float(Stim_RT[i]))
						
					elif StimType[i] == "Body":
						if Proc_Block[i-1] != "TrialsPROC":
							EV10.write(str(Onset_Time_Sec)+"	"+"27.5"+"	"+"1"+"\n")
						ACC_Two_Median[3].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							RT_Two_Median[3].append(float(Stim_RT[i]))
					
			if Proc_Block[i] == "TrialsPROC":
				if BlockType[i] == "0-Back":
					Onset_Time_Sec = int(Stim_Onset[i])/1000.0 - Sync_Val
					if Stim_Resp[i] != Corr_Resp[i]:
						EV11.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
					elif Stim_Resp[i] == Corr_Resp[i]:
						EV1.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
						
					if Stim_Resp[i] == '""':
						EV13.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
					
				elif BlockType[i] == "2-Back":
					#correct stats for all 2-back blocks
					#if the image matches two images previous
					if ImageName[i] == ImageName[i-2]:
						#if the response given was "target"
						if Stim_Resp[i] == "b":
							#accuracy is actually 1
							Corr_Resp[i] = "b"
							
							
					Onset_Time_Sec = int(Stim_Onset[i])/1000.0 - Sync_Val
					if Stim_Resp[i] != Corr_Resp[i]:
						EV12.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
					elif Stim_Resp[i] == Corr_Resp[i]:
						EV2.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
						
					if Stim_Resp[i] == '""':
						EV14.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
								
		
		try:
			Zero_RT_Faces_Median = sum(RT_Zero_Median[0])/len(RT_Zero_Median[0])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_RT_Faces_Median = -555
			
		try:
			Zero_RT_Places_Median = sum(RT_Zero_Median[1])/len(RT_Zero_Median[1])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_RT_Places_Median = -555
			
		try:
			Zero_RT_Tools_Median = sum(RT_Zero_Median[2])/len(RT_Zero_Median[2])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_RT_Tools_Median = -555
			
		try:
			Zero_RT_BP_Median = sum(RT_Zero_Median[3])/len(RT_Zero_Median[3])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_RT_BP_Median = -555
		
		try:
			Two_RT_Faces_Median = sum(RT_Two_Median[0])/len(RT_Two_Median[0])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_RT_Faces_Median = -555
			
		try:
			Two_RT_Places_Median = sum(RT_Two_Median[1])/len(RT_Two_Median[1])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_RT_Places_Median = -555
			
		try:
			Two_RT_Tools_Median = sum(RT_Two_Median[2])/len(RT_Two_Median[2])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_RT_Tools_Median = -555
		
		try:
			Two_RT_BP_Median = sum(RT_Two_Median[3])/len(RT_Two_Median[3])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_RT_BP_Median = -555
	
		try:
			Zero_ACC_Faces_Median = sum(ACC_Zero_Median[0])/len(ACC_Zero_Median[0])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_ACC_Faces_Median = -555
		
		try:
			Zero_ACC_Places_Median = sum(ACC_Zero_Median[1])/len(ACC_Zero_Median[1])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_ACC_Faces_Median = -555
		
		try:
			Zero_ACC_Tools_Median = sum(ACC_Zero_Median[2])/len(ACC_Zero_Median[2])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_ACC_Tools_Median = -555
		
		try:
			Zero_ACC_BP_Median = sum(ACC_Zero_Median[3])/len(ACC_Zero_Median[3])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Zero_ACC_BP_Median = -555
		
		try:
			Two_ACC_Faces_Median = sum(ACC_Two_Median[0])/len(ACC_Two_Median[0])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_ACC_Faces_Median = -555
			
		try:
			Two_ACC_Places_Median = sum(ACC_Two_Median[1])/len(ACC_Two_Median[1])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_ACC_Places_Median = -555
		
		try:
			Two_ACC_Tools_Median = sum(ACC_Two_Median[2])/len(ACC_Two_Median[2])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_ACC_Tools_Median = -555
			
		try:
			Two_ACC_BP_Median = sum(ACC_Two_Median[3])/len(ACC_Two_Median[3])
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Two_ACC_BP_Median = -555
			
		templist = [Zero_RT_BP_Median,Zero_RT_Faces_Median,Zero_RT_Places_Median,Zero_RT_Tools_Median,
					Two_RT_BP_Median,Two_RT_Faces_Median,Two_RT_Places_Median,Two_RT_Tools_Median]
					
		for item in templist:
			if item == 0:
				item = -555
	
		Stats.write("0-Back BP Median ACC: " + str(Zero_ACC_BP_Median)+"\n")
		Stats.write("0-Back Faces Median ACC: " + str(Zero_ACC_Faces_Median)+"\n")
		Stats.write("0-Back Places Median ACC: " + str(Zero_ACC_Places_Median)+"\n")
		Stats.write("0-Back Tools Median ACC: " + str(Zero_ACC_Tools_Median)+"\n")
		Stats.write("========================\n")
		Stats.write("2-Back BP Median ACC: " + str(Two_ACC_BP_Median)+"\n")
		Stats.write("2-Back Faces Median ACC: " + str(Two_ACC_Faces_Median)+"\n")
		Stats.write("2-Back Places Median ACC: " + str(Two_ACC_Places_Median)+"\n")
		Stats.write("2-Back Tools Median ACC: " + str(Two_ACC_Tools_Median)+"\n")
		Stats.write("========================\n")
		Stats.write("0-Back BP Median RT: " + str(Zero_RT_BP_Median)+"\n")
		Stats.write("0-Back Faces Median RT: " + str(Zero_RT_Faces_Median)+"\n")
		Stats.write("0-Back Places Median RT: " + str(Zero_RT_Places_Median)+"\n")
		Stats.write("0-Back Tools Median RT: " + str(Zero_RT_Tools_Median)+"\n")
		Stats.write("========================\n")
		Stats.write("2-Back BP Median RT: " + str(Two_RT_BP_Median)+"\n")
		Stats.write("2-Back Faces Median RT: " + str(Two_RT_Faces_Median)+"\n")
		Stats.write("2-Back Places Median RT: " + str(Two_RT_Places_Median)+"\n")
		Stats.write("2-Back Tools Median RT: " + str(Two_RT_Tools_Median)+"\n")
	
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