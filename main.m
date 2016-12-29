function [] = main()
    tic;
    sP = setSystemParameters();
    
    numberOfSDChains = size(sP.SDChain, 1);
    
    nPside = zeros(numberOfSDChains, 1);
    QYield = zeros(numberOfSDChains, 1);
    EFQ    = zeros(numberOfSDChains, 1);
    for j = 1:numberOfSDChains
        sS0 = setSystemInitialState(1, j, sP);

        [dynamicsOutput, cumulativeOutput] = runSimulation(sP, sS0);
        cumulativeOutput
        nPside(j) = cumulativeOutput.nPside;
        QYield(j) = cumulativeOutput.QY;
        EFQ(j)    = cumulativeOutput.EFQ;
    end
    
    sDChain = sP.SDChain;
    save QCycleTestOutput.mat sDChain nPside QYield EFQ
    
    %plot(sP.SDChain, nPside);
    plot(sP.SDChain, QYield);
    %plot(sP.SDChain, EFQ);
    toc;
end

function [dynamicsOutput, cumulativeOutput] = runSimulation(sP, sS)
    % Simulation cycle
    % definition of output array
    f1 = 'quinonePosition'; v1 = zeros(1, sP.nOS);
    f2 = 'nA';              v2 = zeros(1, sP.nOS);
    f3 = 'nB';              v3 = zeros(1, sP.nOS);
    f4 = 'nL';              v4 = zeros(1, sP.nOS);
    f5 = 'nH';              v5 = zeros(1, sP.nOS);
    f6 = 'n1Q';             v6 = zeros(1, sP.nOS);
    f7 = 'n2Q';             v7 = zeros(1, sP.nOS);
    f8 = 'N1Q';             v8 = zeros(1, sP.nOS);
    f9 = 'N2Q';             v9 = zeros(1, sP.nOS);
    
    % ?????????????? what are those 3?
    f10 = 'dnBB';           v10 = zeros(1, sP.nOS);
    f11 = 'WNb';            v11 = zeros(1, sP.nOS);
    f12 = 'WPb';            v12 = zeros(1, sP.nOS);
    
    % currents
    f13 = 'CurrS';          v13 = zeros(1, sP.nOS);
    f14 = 'CurrD';          v14 = zeros(1, sP.nOS);
    
    f15 = 'dnN';            v15 = zeros(1, sP.nOS);
    f16 = 'dnP';            v16 = zeros(1, sP.nOS);
    
    for time = 2:sP.nOS
        OmegaQ = calculateQuinoneFrequencies(sP, sS);
        
        [gammaA, gammaB] = calculateABGammas(sS, sP, OmegaQ);
        
        gammaLH = calculateLHGamma(sP, sS, OmegaQ);
        
        [gammaQ, WNpr, WPpr] = calculateQuinoneGamma(sP, sS, OmegaQ);
        
%        OmegaQ
%        gammaA
%        gammaB
%        gammaLH
%        gammaQ
%        WNpr
%        WPpr
%        pause(10)
        sS = changeSystemState(sS, sP, gammaA, gammaB, gammaLH, gammaQ);
        
        %% Fill in the output array
        v1(time + 1) = sS.quinonePosition;
        v2(time + 1) = sS.systemStates.ASite;
        v3(time + 1) = sS.systemStates.BSite;
        v4(time + 1) = sum(sP.populationOperators.nL * sS.systemStates.LHSystem);
        v5(time + 1) = sum(sP.populationOperators.nH * sS.systemStates.LHSystem);
        v6(time + 1) = sum(sP.populationOperators.n1 * sS.systemStates.Quinone);
        v7(time + 1) = sum(sP.populationOperators.n2 * sS.systemStates.Quinone);
        v8(time + 1) = sum(sP.populationOperators.N1 * sS.systemStates.Quinone);
        v9(time + 1) = sum(sP.populationOperators.N2 * sS.systemStates.Quinone);
        v10(time + 1) = v8(time) - v8(time - 1) + v9(time) - v9(time - 1);
        v11(time + 1) = WNpr;
        v12(time + 1) = WPpr;
        
        LimNum = sP.lambdas.LimNum;
        if WNpr > LimNum
            v15(time + 1) = - v10(time);
        end
        if WPpr > LimNum
            v16(time + 1) = - v10(time);
        end
        
        v13(time + 1) = sP.meVtoTime * sP.gammas.gamS * (v2(time) - sS.gammas.fSeA);
        v14(time + 1) = sP.meVtoTime * sP.gammas.gamD * (v3(time) - sS.gammas.fBeD);
    end
    
    dynamicsOutput = struct(f1, v1, f2, v2, f3, v3, f4, v4, ...
        f5, v5, f6, v6, f7, v7, f8, v8, f9, v9, f10, v10, ...
        f11, v11, f12, v12, f13, v13, f14, v14, f15, v15, f16, v16);
    % Cumulative output
    f1 = 'nPside';
    tmpV = cumsum(v16);
    v1 = tmpV(sP.nOS);
    
    f2 = 'nDrain';
    tmpV = sP.dt * cumsum(v14);
    v2 = tmpV(sP.nOS);

    f3 = 'QY'; v3 = v1 ./ v2;
    
    muP = sS.chemicalPotentials.P;
    muN = sS.chemicalPotentials.N;
    muS = sS.chemicalPotentials.S;
    muD = sS.chemicalPotentials.D;
    
    f4 = 'EFQ'; v4 = v3 .* (muP - muN) ./ (muS - muD);
    
    cumulativeOutput = struct(f1, v1, f2, v2, f3, v3, f4, v4);
end