import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency for task
	if openfile.find("GAMB_ER") != -1 or openfile.find("GAMB-ER") != -1:
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
		Proc_Trial = []
		TrialType = []
		QM_Onset = []
		Fix_Onset = []
		Sync_Onset = []
		QM_RTTime = []
		Sync_Val = False
		QM_Resp = []
		RT = []
		Total_Responses = 0.0
		NLR = []
		NLR_Total = 0.0
	
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
			 	PB_Index = i
			elif num_columns[i] == "Procedure[Trial]":
				PT_Index = i
			elif num_columns[i] == "TrialType":
				TT_Index = i
			elif num_columns[i] == "QuestionMark.OnsetTime":
				QM_Index = i
			elif num_columns[i] == "FillerFixation.OnsetTime":
				FF_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "QuestionMark.RT" or num_columns[i] == "QuestionMark.RTTime":
				QMRT_Index = i
			elif num_columns[i] == "QuestionMark.RESP":
				QMR_Index = i
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/win.txt','w')
		EV2 = open(str(sys.argv[2]) + '/neut.txt','w')
		EV3 = open(str(sys.argv[2]) + '/loss.txt','w')
		EV4 = open(str(sys.argv[2]) + '/win_rt.txt','w')
		EV5 = open(str(sys.argv[2]) + '/neut_rt.txt','w')
		EV6 = open(str(sys.argv[2]) + '/loss_rt.txt','w')
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
	
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): 
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == PT_Index:
					Proc_Trial.append(tempdata[j])
				elif j == TT_Index:
					TrialType.append(tempdata[j])
				elif j == QM_Index:
					QM_Onset.append(tempdata[j])
				elif j == FF_Index:
					Fix_Onset.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == QMRT_Index:
					QM_RTTime.append(tempdata[j])
				elif j == QMR_Index:
					QM_Resp.append(tempdata[j])
				
		for i in range(len(Proc_Trial)):
		
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
		
			if Proc_Block[i] == "Run1PROC" and Proc_Block[i-1] == "TRSyncPROC":
				#you are in a trial
				#set first index
				First_Index = i
				First_Onset = QM_Onset[i]
				print ("First Onset set to: " + str(int(First_Onset)/1000.0))
						
			if Proc_Trial[i] == "GamblingTrialPROC":
				#set onset
				Onset_Time_Sec = int(QM_Onset[i])/1000.0 - Sync_Val
				RT_Time_Sec = int(QM_RTTime[i])/1000.0
			
				if TrialType[i] == "Reward":
					EV1.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
					EV4.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+str(RT_Time_Sec)+"\n")
				elif TrialType[i] == "Neutral":
					EV2.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
					EV5.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+str(RT_Time_Sec)+"\n")
				elif TrialType[i] == "Punishment":
					EV3.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
					EV6.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+str(RT_Time_Sec)+"\n")
						
				if QM_RTTime[i] != '0' and QM_RTTime[i] != "":
					RT.append(float(QM_RTTime[i]))
				else:
					NLR.append(1.0)
				
				Total_Responses = Total_Responses + 1.0
			
		try:
			RT = sum(RT)/float(len(RT))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			RT = -555
			
		Num_NLR = sum(NLR)
		
		try:
			NLR_Total = (Num_NLR/float(Total_Responses))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			NLR_Total = -555
		
		try:
			NLR_ACC = 1.0 - (Num_NLR/float(Total_Responses))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			NLR_ACC = -555
			
		Stats.write("Mean RT: " + str(RT)+"\n")
		Stats.write("Percent NLR: " + str(NLR_Total) +"\n")
		Stats.write("NLR as ACC: " + str(NLR_ACC)+"\n")
	
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
		EV5.close()
		EV6.close()
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")
		
if __name__ == "__main__":
	main()