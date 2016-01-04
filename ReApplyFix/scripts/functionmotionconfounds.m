function confounds = functionmotionconfounds(TR, hp)

if (isdeployed)
    if isstr(hp)
        hp = str2num(hp)
    end
    if isstr(TR)
        TR = str2num(TR)
    end
end

func_name='functionmotionconfounds';
fprintf('%s - TR: %d\n', func_name, TR);
fprintf('%s - hp: %d\n', func_name, hp);

%%%% must have "hp" and "TR" already set before calling this

[grota,grotb]=call_fsl('imtest mc/prefiltered_func_data_mcf_conf_hp');

if grotb==1

  confounds=read_avw('mc/prefiltered_func_data_mcf_conf_hp');
  confounds=functionnormalise(reshape(confounds,size(confounds,1),size(confounds,4))');

else

  confounds=load('mc/prefiltered_func_data_mcf.par');
  confounds=confounds(:,1:6);
  %confounds=functionnormalise(confounds(:,std(confounds)>0.000001)); % remove empty columns
  confounds=functionnormalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
  confounds=functionnormalise([confounds confounds.*confounds]);

  if hp==0
    confounds=detrend(confounds);
  end
  if hp>0
    save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),'mc/prefiltered_func_data_mcf_conf','f',[1 1 1 TR]);

    %call_fsl(sprintf('fslmaths mc/prefiltered_func_data_mcf_conf -bptf %f -1 mc/prefiltered_func_data_mcf_conf_hp',0.5*hp/TR));
    cmd_str=sprintf('fslmaths mc/prefiltered_func_data_mcf_conf -bptf %f -1 mc/prefiltered_func_data_mcf_conf_hp',0.5*hp/TR);
    fprintf('%s - About to execute: %s\n',func_name,cmd_str);
    system(cmd_str);	

    confounds=functionnormalise(reshape(read_avw('mc/prefiltered_func_data_mcf_conf_hp'),size(confounds,2),size(confounds,1))');
  end
end

