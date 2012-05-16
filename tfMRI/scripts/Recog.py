import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("REC") != -1:
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
		StimType = []
		Stim_OnsetTime = []
		Stim_ACC = []
		Stim_RESP =[]
		Stim_RT = []
		Stim_CRESP = []
		Sync_Onset = []
		Median_RT = [ [], [], [] ]
		ACC_Foils = []
		Percent_Old = [ [], [] ]
		Sync_Val = False
		Total_Old_Responses = 0.0
		NLR = []
		Total_Responses = 0.0
	
		ACC_NewFace = []
		ACC_NewPlace = []
		Per_Know_OldFace = []
		Per_Rem_OldFace = []
		Per_Know_OldPlace = []
		Per_Rem_OldPlace = []
		MeanRT_KnowOldFace = []
		MeanRT_KnowOldPlace = []
		MeanRT_NewFace = []
		MeanRT_NewPlace = []
		MeanRT_RemOldFace = []
		MeanRT_RemOldPlace = []
	
		Total_OF_Resp = 0.0
		Total_OP_Resp = 0.0
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
			 	PB_Index = i
			elif num_columns[i] == "StimType":
				ST_Index = i
			elif num_columns[i] == "Stim.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "Stim.ACC":
				SA_Index = i
			elif num_columns[i] == "Stim.RESP":
				SR_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SYO_Index = i
			elif num_columns[i] == "Stim.RT":
				RT_Index = i
			elif num_columns[i] == "Stim.CRESP":
				SCR_Index = i
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/cr.txt','w')
		EV2 = open(str(sys.argv[2]) + '/know.txt','w')
		EV3 = open(str(sys.argv[2]) + '/rem.txt','w')
		EV4 = open(str(sys.argv[2]) + '/miss.txt','w')
		EV5 = open(str(sys.argv[2]) + '/faces.txt','w')
		EV6 = open(str(sys.argv[2]) + '/places.txt','w')
		EV7 = open(str(sys.argv[2]) + '/fa.txt','w')
		EV8 = open(str(sys.argv[2]) + '/hit.txt','w')
	
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
	
		EV9 = open(str(sys.argv[2]) + '/cr_rt.txt','w')
		EV10 = open(str(sys.argv[2]) + '/know_rt.txt','w')
		EV11 = open(str(sys.argv[2]) + '/rem_rt.txt','w')
		EV12 = open(str(sys.argv[2]) + '/miss_rt.txt','w')
		EV13 = open(str(sys.argv[2]) + '/faces_rt.txt','w')
		EV14 = open(str(sys.argv[2]) + '/places_rt.txt','w')
		EV15 = open(str(sys.argv[2]) + '/fa_rt.txt','w')
		EV16 = open(str(sys.argv[2]) + '/hit_rt.txt','w')
		
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == ST_Index:
					StimType.append(tempdata[j])
				elif j == SO_Index:
					Stim_OnsetTime.append(tempdata[j])
				elif j == SA_Index:
					Stim_ACC.append(tempdata[j])
				elif j == SR_Index:
					Stim_RESP.append(tempdata[j])
				elif j == SYO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					Stim_RT.append(tempdata[j])
				elif j == SCR_Index:
					Stim_CRESP.append(tempdata[j])
				
		for i in range(len(Proc_Block)):
		
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
		
			if Proc_Block[i] == "RecMemTrialsPROC" and Proc_Block[i-1] == "TRSyncPROC":
				#you are in a trial
				#set first index
				First_Index = i
				First_Onset = Stim_OnsetTime[i]
				print ("First Onset set to: " + str(int(First_Onset)/1000.0))
			
			
			if Proc_Block[i] == "RecMemTrialsPROC" and Stim_OnsetTime[i] != "":
				#set onset
				Onset_Time_Sec = (int(Stim_OnsetTime[i])/1000.0) - Sync_Val
				RT_Time_Sec = int(Stim_RT[i])/1000.0
			
			
				if StimType[i][:3] == "new" and Stim_RESP[i] == "4" and Stim_ACC[i] == "1":
					EV1.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV9.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
				if StimType[i][:3] == "old" and Stim_RESP[i] == "3" and Stim_ACC[i] == "1":
					EV2.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV10.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
				if StimType[i][:3] == "old" and Stim_RESP[i] == "2" and Stim_ACC[i] == "1":
					EV3.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV11.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
				if StimType[i][:3] == "new" and Stim_ACC[i] == "0":
					EV7.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV15.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
				if StimType[i][:3] == "old" and Stim_ACC[i] == "0":
					EV4.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV12.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
				if StimType[i][:3] == "old" and Stim_ACC[i] == "1":
					EV8.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV16.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
				
				
				if StimType[i][:3] == "new" and Stim_RESP[i] == "4":
					ACC_Foils.append(float(Stim_ACC[i]))
				
				if StimType[i][:3] == "old" and Stim_RESP[i] == "2":
					Percent_Old[0].append(1.0)
					if StimType[i][3:] == "face":
						Per_Rem_OldFace.append(1.0)
						Total_OF_Resp = Total_OF_Resp + 1.0
						if Stim_ACC[i] == "1":
							MeanRT_RemOldFace.append(float(Stim_RT[i]))
					
					elif StimType[i][3:] == "place":
						Per_Rem_OldPlace.append(1.0)
						Total_OP_Resp = Total_OP_Resp + 1.0
						if Stim_ACC[i] == "1":
							MeanRT_RemOldPlace.append(float(Stim_RT[i]))
					
				if StimType[i][:3] == "old" and Stim_RESP[i] == "3":
					Percent_Old[1].append(1.0)
					if StimType[i][3:] == "face":
						Per_Know_OldFace.append(1.0)
						Total_OF_Resp = Total_OF_Resp + 1.0
						if Stim_ACC[i] == "1":
							MeanRT_KnowOldFace.append(float(Stim_RT[i]))
					
					elif StimType[i][3:] == "place":
						Per_Know_OldPlace.append(1.0)
						Total_OP_Resp = Total_OP_Resp + 1.0
						if Stim_ACC[i] == "1":
							MeanRT_KnowOldPlace.append(float(Stim_RT[i]))
					
				if StimType[i][:3] == "new" and Stim_ACC[i] == "1":
					Median_RT[0].append(float(Stim_RT[i]))
				if StimType[i][:3] == "old" and Stim_RESP[i] == "3":
					Median_RT[1].append(float(Stim_RT[i]))
				if StimType[i][:3] == "old" and Stim_RESP[i] == "2":
					Median_RT[2].append(float(Stim_RT[i]))
								
				if StimType[i][3:] == "face":
					EV5.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV13.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
					if StimType[i][:3] == "new":
						ACC_NewFace.append(int(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							MeanRT_NewFace.append(float(Stim_RT[i]))
						
				elif StimType[i][3:] == "place":
					EV6.write(str(Onset_Time_Sec)+"	"+"2"+"	"+"1"+"\n")
					EV14.write(str(Onset_Time_Sec)+"	"+"2"+"	"+str(RT_Time_Sec)+"\n")
					if StimType[i][:3] == "new":
						ACC_NewPlace.append(int(Stim_ACC[i]))
						if Stim_ACC[i] == "1":
							MeanRT_NewPlace.append(float(Stim_RT[i]))
			
				if Stim_CRESP[i] != "4" and StimType[i][:3] == "old" and Stim_RT[i] != "0":
					Total_Old_Responses = Total_Old_Responses + 1.0
				
				if Stim_RT[i] == "0":
					NLR.append(StimType[i])
				if Stim_CRESP[i] != "0":
					Total_Responses = Total_Responses + 1.0
		
		for i in range(len(Median_RT)):
			if len(Median_RT[i]) != 0:
				Median_RT[i] = sum(Median_RT[i])/len(Median_RT[i])
			elif len(Median_RT) == 0:
				Median_RT[i] = -555
		try:
			Percent_Old[0] = sum(Percent_Old[0])/float(Total_Old_Responses) 
		except ZeroDivisionError:
			Percent_Old[0] = -555
		
		try:
			Percent_Old[1] = sum(Percent_Old[1])/float(Total_Old_Responses) 
		except ZeroDivisionError:
			Percent_Old[1] = -555
			
		try:
			NLR_Percent = float(len(NLR))/float(Total_Responses) 
		except ZeroDivisionError:
			NLR_Percent = -555
			
	
		try:
			ACC_Foils = sum(ACC_Foils)/len(ACC_Foils)
		except ZeroDivisionError:
			ACC_Foils = -555
		try:
			ACC_NewFace = sum(ACC_NewFace)/float(len(ACC_NewFace))
		except ZeroDivisionError:
			ACC_NewFace = -555
		try:
			ACC_NewPlace = sum(ACC_NewPlace)/float(len(ACC_NewPlace))
		except ZeroDivisionError:
			ACC_NewPlace = -555
	
		try:
			Per_Know_OldFace = sum(Per_Know_OldFace)/Total_OF_Resp
		except ZeroDivisionError:
			Per_Know_OldFace = -555
		
		try:
			Per_Rem_OldFace = sum(Per_Rem_OldFace)/Total_OF_Resp
		except ZeroDivisionError:
			Per_Rem_OldFace = -555
		
		try:
			Per_Know_OldPlace = sum(Per_Know_OldPlace)/Total_OP_Resp
		except ZeroDivisionError:
			Per_Know_OldPlace = -555
		
		try:
			Per_Rem_OldPlace = sum(Per_Rem_OldPlace)/Total_OP_Resp
		except ZeroDivisionError:
			Per_Rem_OldPlace = -555
	
		try:
			MeanRT_KnowOldFace = sum(MeanRT_KnowOldFace)/len(MeanRT_KnowOldFace)
		except ZeroDivisionError:
			MeanRT_KnowOldFace = -555
		
		try:
			MeanRT_KnowOldPlace = sum(MeanRT_KnowOldPlace)/len(MeanRT_KnowOldPlace)
		except ZeroDivisionError:
			MeanRT_KnowOldPlace = -555
		
		try:
			MeanRT_NewFace = sum(MeanRT_NewFace)/len(MeanRT_NewFace)
		except ZeroDivisionError:
			MeanRT_NewFace = -555
		
		try:
			MeanRT_NewPlace = sum(MeanRT_NewPlace)/len(MeanRT_NewPlace)
		except ZeroDivisionError:
			MeanRT_NewPlace = -555
		
		try:
			MeanRT_RemOldFace = sum(MeanRT_RemOldFace)/len(MeanRT_RemOldFace)
		except ZeroDivisionError:
			MeanRT_RemOldFace = -555
		
		try:
			MeanRT_RemOldPlace = sum(MeanRT_RemOldPlace)/len(MeanRT_RemOldPlace)
		except ZeroDivisionError:
			MeanRT_RemOldPlace = -555
		
	
		Stats.write("Accuracy New Face: " + str(ACC_NewFace)+ "\n")
		Stats.write("Accuracy New Place: "+ str(ACC_NewPlace)+ "\n")
		Stats.write("%Know_OldFace: " + str(Per_Know_OldFace)+ "\n")
		Stats.write("%Rem_OldFace: " +str(Per_Rem_OldFace)+ "\n")
		Stats.write("%Know_OldPlace: " +str(Per_Know_OldPlace)+ "\n")
		Stats.write("%Rem_OldPlace:" +str(Per_Rem_OldPlace)+ "\n")
		Stats.write("Mean RT Know Old Face: " + str(MeanRT_KnowOldFace)+ "\n")
		Stats.write("Mean RT Know Old Place: " + str(MeanRT_KnowOldPlace)+ "\n")
		Stats.write("Mean RT New Face: " + str(MeanRT_NewFace)+ "\n")
		Stats.write("Mean RT New Place: " + str(MeanRT_NewPlace)+ "\n")
		Stats.write("Mean RT Rem Old Face: " + str(MeanRT_RemOldFace)+ "\n")
		Stats.write("Mean RT Rem Old Place: " + str(MeanRT_RemOldPlace)+ "\n")
		Stats.write("No Logged Reponse: " + str(NLR_Percent) + "\n")
	
		#Stats.write("Accuracy for Foils: " + str(ACC_Foils) + "\n")
		#Stats.write("=====================\n")
		#Stats.write("Median RT for Foils: " + str(Median_RT[0]) + "\n")
		#Stats.write("Median RT Know to Old: " + str(Median_RT[1]) + "\n")
		#Stats.write("Median RT Remember to Old: " + str(Median_RT[2]) + "\n")
		#Stats.write("=====================\n")
		#Stats.write("Percent Old rated Know: " + str(Percent_Old[0]) + "\n")
		#Stats.write("Precent Old rated Remember: " + str(Percent_Old[1]) + "\n")
		#Stats.write("=====================\n")
				
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
		EV15.close()
		EV16.close()
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")
	
if __name__ == "__main__":
	main()