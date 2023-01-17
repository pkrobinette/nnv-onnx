function verifyP2()

    % Setup the property
    resMAT = [];
    resNNV = [];
    timeMAT = zeros(45,1);
    timeNNV = zeros(45,1);
    timeNNVver = zeros(45,1);
    
    XLower = [0.6; -0.5; -0.5; 0.45; -0.5];
    XUpper = [0.679857769; 0.5; 0.5; 0.5; -0.45];
    
    % NNV
%     IS = Star(XLower, XUpper); % Input set
    IS = ImageStar(XLower, XUpper);
    H = [1 -1 0 0 0; 1 0 -1 0 0; 1 0 0 -1 0; 1 0 0 0 -1];
    g = [0;0;0;0];
    reachOpt = struct;
    reachOpt.reachMethod = 'approx-star';
    
    % MATLAB
    label = 1;
    XLower = dlarray(XLower, "CB");
    XUpper = dlarray(XUpper, "CB");
    
    % Iterate through all the networks to verify
%     acasFolder = "/home/manzand/Documents/MATLAB/vnncomp2022_benchmarks/benchmarks/acasxu/onnx/";
    acasFolder = "/home/dieman95/Documents/MATLAB/vnncomp2022_benchmarks/benchmarks/acasxu/onnx/";
    networks = dir(acasFolder);
    
    for i = 3:length(networks)
        % Load Network
        file = acasFolder + string(networks(i).name);
        net = importONNXNetwork(file, InputDataFormats='BCSS');

        % transform into NNV
        netNNV = matlab2nnv(net);

        % Transform the layers to fit MATLAB's algorithm
        Layers = net.Layers;
        Layers = Layers(5:end-1); % remove input and output layers
        input_layer = featureInputLayer(5); % number of inputs to acas xu
        elem_idxs = 2:3:length(Layers); % elementwiseLayers position
        for k=elem_idxs
            Layers(k-1).Bias = Layers(k).Offset; % add offset as bias on previous layer
        end
        Layers(elem_idxs) = []; % remove elementwiselayer
        netMAT = dlnetwork([input_layer; Layers]); % create dlnetwork for verification

        % Verify MATLAB
        t = tic;
        res = verifyNetworkRobustness(netMAT, XLower, XUpper, label);
        timeMAT(i-2) = toc(t);
        resMAT = [resMAT; res];
        
        % Verify NNV
        t = tic;
        R = netNNV.reach(IS, reachOpt);
        timeNNV(i-2) = toc(t);
        R = R.toStar;
        t = tic;
        disp(' ');
        disp("Verification of " + string(networks(i).name));
        res = verifyNNV(R, H, g);
        timeNNVver(i-2) = toc(t);
        resNNV = [resNNV; res];
        
        
    end

    % Save results
    save("results_p2", "resMAT", "resNNV", "timeMAT", "timeNNV", "timeNNVver");

end

%% Helper Function
% function result = verifyNNV(R) % simple (work on the VNNLIB and intersection with halfspaces to automate this process)
% 
%     [YLower, YUpper] = R.getRanges();
%     if YUpper(1) < YLower(2) || YUpper(1) < YLower(3) || YUpper(1) < YLower(4) || YUpper(1) < YLower(5)
%         result = categorical("violated"); % violated = safe
% 
%     elseif YLower(1) > YUpper(2) && YLower(1) > YUpper(3) && YLower(1) > YUpper(4) && YLower(1) > YUpper(5)
%         result = categorical("verified"); % verified = unsafe
%     
%     else
%         result = categorical("unproven"); % if approx methods used, then unproven, otherwise (exact) violated
%     end
% 
% end

function result = verifyNNV(Set, H, b)
    S = Set.intersectHalfSpace(H,b);
    if isempty(S)
        result = categorical("violated");
    elseif Set.isSubSet(S)
        result = categorical("verified");
    else
        result = categorical("unproven");
    end
end
