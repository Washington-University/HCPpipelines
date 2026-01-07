function fMRIStats(MeanCIFTI,MeanVolume,sICATCS,Signal,OrigCIFTITCS,OrigVolumeTCS,CleanedCIFTITCS,CleanedVolumeTCS,CIFTIOutputName,VolumeOutputName,CleanUpEffects,ProcessVolume,Caret7_Command)

  MeanCIFTI = ciftiopen(MeanCIFTI,Caret7_Command);
  sICATCS = ciftiopen(sICATCS,Caret7_Command);
  Signal = load(Signal);
  CleanedCIFTITCS = ciftiopen(CleanedCIFTITCS,Caret7_Command);
  sICATCSSignal = sICATCS.cdata(Signal,:)';

  if strcmp(CleanUpEffects,'YES')
    OrigCIFTITCS = ciftiopen(OrigCIFTITCS,Caret7_Command);
    OrigCIFTITCS.cdata = demean(OrigCIFTITCS.cdata,2);
  end

  if strcmp(ProcessVolume,'YES')
    VolumeGeometryName = MeanVolume;
    MeanVolume = read_avw(MeanVolume);
    CleanedVolumeTCS = read_avw(CleanedVolumeTCS);
    MeanVolume2D = reshape(MeanVolume,size(MeanVolume,1) * size(MeanVolume,2) * size(MeanVolume,3),1);
    CleanedVolumeTCS2D = reshape(CleanedVolumeTCS,size(MeanVolume,1) * size(MeanVolume,2) * size(MeanVolume,3),size(CleanedVolumeTCS,4));
    MASK = MeanVolume2D ~= 0;
    MeanVolume2DMasked = MeanVolume2D(MASK);
    CleanedVolumeTCS2DMasked = CleanedVolumeTCS2D(MASK,:);
    clear CleanedVolumeTCS CleanedVolumeTCS2D
    if strcmp(CleanUpEffects,'YES')
      OrigVolumeTCS = read_avw(OrigVolumeTCS);
      OrigVolumeTCS2D = reshape(OrigVolumeTCS,size(MeanVolume,1) * size(MeanVolume,2) * size(MeanVolume,3),size(OrigVolumeTCS,4));
      OrigVolumeTCS2DMasked = OrigVolumeTCS2D(MASK,:);
      OrigVolumeTCS2DMasked = demean(OrigVolumeTCS2DMasked,2);
      clear OrigVolumeTCS OrigVolumeTCS2D        
    end
  end

  CIFTIOutput = MeanCIFTI;

  CIFTIBetas = MeanCIFTI;
  CIFTIBetas.cdata = (pinv(sICATCSSignal) * CleanedCIFTITCS.cdata')';
  CIFTIRecon = CleanedCIFTITCS;
  CIFTIRecon.cdata = CIFTIBetas.cdata * sICATCSSignal';
  ReconSTD = std(CIFTIRecon.cdata,[],2);
  CIFTIUnstruct = CleanedCIFTITCS;
  CIFTIUnstruct.cdata = CleanedCIFTITCS.cdata-CIFTIRecon.cdata;
  UnstructSTD = std(CIFTIUnstruct.cdata,[],2);

  mTSNR = MeanCIFTI.cdata ./ UnstructSTD;
  fCNR = ReconSTD ./ UnstructSTD;
  PercBOLD = ReconSTD ./ MeanCIFTI.cdata * 100;

  if strcmp(CleanUpEffects,'YES')
    CIFTIStruct = CleanedCIFTITCS;
    CIFTIStruct.cdata = OrigCIFTITCS.cdata-CleanedCIFTITCS.cdata;
    StructSTD = std(CIFTIStruct.cdata,[],2);
    CIFTIStructUnstruct = CleanedCIFTITCS;
    CIFTIStructUnstruct.cdata = OrigCIFTITCS.cdata-CIFTIRecon.cdata;
    StructUnstructSTD = std(CIFTIStructUnstruct.cdata,[],2);
    mTSNROrig = MeanCIFTI.cdata ./ StructUnstructSTD;
    fCNROrig = ReconSTD ./ StructUnstructSTD;
    Ratio = StructUnstructSTD ./ UnstructSTD;
    
    CIFTIOutput.cdata = [MeanCIFTI.cdata UnstructSTD ReconSTD mTSNR fCNR PercBOLD StructSTD StructUnstructSTD mTSNROrig fCNROrig Ratio];
    CIFTIOutput.diminfo{1,2} = cifti_diminfo_make_scalars(size(CIFTIOutput.cdata,2),...
      {'Mean','UnstructuredNoiseSTD','SignalSTD','ModifiedTSNR','FunctionalCNR','PercentBOLD','StructuredArtifactSTD','StructuredAndUnstructuredSTD','UncleanedTSNR','UncleanedFunctionalCNR','CleanUpRatio'});
    else
    CIFTIOutput.cdata = [MeanCIFTI.cdata UnstructSTD ReconSTD mTSNR fCNR PercBOLD];
    CIFTIOutput.diminfo{1,2} = cifti_diminfo_make_scalars(size(CIFTIOutput.cdata,2),...
      {'Mean','UnstructuredNoiseSTD','SignalSTD','ModifiedTSNR','FunctionalCNR','PercentBOLD'});
  end

  ciftisave(CIFTIOutput,CIFTIOutputName,Caret7_Command);


  if strcmp(ProcessVolume,'YES')
    VolumeBetas2DMasked = (pinv(sICATCSSignal) * CleanedVolumeTCS2DMasked')';
    VolumeRecon2DMasked = VolumeBetas2DMasked * sICATCSSignal';
    ReconSTD = std(VolumeRecon2DMasked,[],2);
    VolumeUnstruct2DMasked = CleanedVolumeTCS2DMasked-VolumeRecon2DMasked;
    UnstructSTD = std(VolumeUnstruct2DMasked,[],2);

    mTSNR = MeanVolume2DMasked ./ UnstructSTD;
    fCNR = ReconSTD ./ UnstructSTD;
    PercBOLD = ReconSTD ./ MeanVolume2DMasked * 100;


    if strcmp(CleanUpEffects,'YES')
      VolumeStruct2DMasked = OrigVolumeTCS2DMasked-CleanedVolumeTCS2DMasked;
      StructSTD = std(VolumeStruct2DMasked,[],2);
      VolumeStructUnstruct2DMasked = OrigVolumeTCS2DMasked-VolumeRecon2DMasked;
      StructUnstructSTD = std(VolumeStructUnstruct2DMasked,[],2);
      mTSNROrig = MeanVolume2DMasked ./ StructUnstructSTD;
      fCNROrig = ReconSTD ./ StructUnstructSTD;
      Ratio = StructUnstructSTD ./ UnstructSTD;
        
      VolumeOutput2DMasked = [MeanVolume2DMasked UnstructSTD ReconSTD mTSNR fCNR PercBOLD StructSTD StructUnstructSTD mTSNROrig fCNROrig Ratio];
      else
      VolumeOutput2DMasked = [MeanVolume2DMasked UnstructSTD ReconSTD mTSNR fCNR PercBOLD];
    end
    
    VolumeOutput2D = single(zeros(length(MeanVolume2D),size(VolumeOutput2DMasked,2)));
    VolumeOutput2D(MASK,:) = VolumeOutput2DMasked;
    VolumeOutput = reshape(VolumeOutput2D,size(MeanVolume,1),size(MeanVolume,2),size(MeanVolume,3),size(VolumeOutput2DMasked,2));
    save_avw(VolumeOutput,VolumeOutputName,'f',[1 1 1 1]);
    unix(['fslcpgeom ' VolumeGeometryName ' ' VolumeOutputName ' -d']);
  end

end

