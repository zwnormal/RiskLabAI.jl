using Distributions
using Random
using Statistics
using SymPy

"""
Calculate the Sharpe ratio as a function of the number of bets.
Reference: De Prado, M. (2018) Advances in financial machine learning. Page 213, Snippet 15.1
"""
function sharpeRatioTrials(p, nRun)
    result = []
    for i in 1:nRun
        b = Binomial(1, p)
        random = rand(b, 1)
        if random[1] == 1
            x = 1
        else 
            x = -1
        end
        append!(result, [x])
    end
    return (mean(result), std(result), mean(result) / std(result))
end 

"""
Use the SymPy library for symbolic operations.
Reference: De Prado, M. (2018) Advances in financial machine learning. Page 214, Snippet 15.2
"""
function targetSharpeRatioSymbolic()
    p, u, d = symbols("p u d")
    m2 = p * u^2 + (1 - p) * d^2
    m1 = p * u + (1 - p) * d
    v = m2 - m1^2
    factor(v) 
end

"""
Compute implied precision.
Reference: De Prado, M. (2018) Advances in financial machine learning. Page 214, Snippet 15.3
"""
function impliedPrecision(
        stopLoss,
        profitTaking,
        freq,
        targetSharpeRatio
    )

    a = (freq + targetSharpeRatio^2) * (profitTaking - stopLoss)^2
    b = (2 * freq * stopLoss - targetSharpeRatio^2 * (profitTaking - stopLoss)) * (profitTaking - stopLoss)
    c = freq * stopLoss^2
    precision = (-b + (b^2 - 4 * a * c)^0.5) / (2 * a)
    return precision
end

"""
Compute the number of bets per year needed to achieve a Sharpe ratio with a certain precision rate.
Reference: De Prado, M. (2018) Advances in financial machine learning. Page 215, Snippet 15.4
"""
function binFrequency(
        stopLoss,
        profitTaking,
        precision,
        targetSharpeRatio
    )

    freq = (targetSharpeRatio * (profitTaking - stopLoss))^2 * precision * (1 - precision) / ((profitTaking - stopLoss) * precision + stopLoss)^2
    binSr(sl0, pt0, freq0, p0) = (((pt0 - sl0) * p0 + sl0) * freq0^0.5) / ((pt0 - sl0) * (p0 * (1 - p0))^0.5)
    if !isapprox(binSr(stopLoss, profitTaking, freq, precision), targetSharpeRatio, atol = 0.5)
        return nothing
    end
    return freq
end

"""
Calculate the strategy risk in practice.
Reference: De Prado, M. (2018) Advances in financial machine learning. Page 215, Snippet 15.4
"""
function mixGaussians(
        μ1,
        μ2,
        σ1,
        σ2,
        probability1,
        nObs
    )

    return1 = rand(Normal(μ1, σ1), trunc(Int, nObs * probability1))
    return2 = rand(Normal(μ2, σ2), trunc(Int, nObs) - trunc(Int, nObs * probability1))
    returns = append!(return1, return2)
    shuffle!(returns)
    return returns
end 

function failureProbability(returns, freq, targetSharpeRatio)
    rPositive, rNegative = mean(returns[returns .> 0]), mean(returns[returns .<= 0])
    p = size(returns[returns .> 0], 1) / size(returns, 1)
    thresholdP = impliedPrecision(rNegative, rPositive, freq, targetSharpeRatio)
    risk = cdf(Normal(p, p * (1 - p)), thresholdP)
    return risk
end

function calculateStrategyRisk(
        μ1,
        μ2,
        σ1,
        σ2,
        probability1,
        nObs,
        freq,
        targetSharpeRatio
    )
    
    returns = mixGaussians(μ1, μ2, σ1, σ2, probability1, nObs)
    probabilityFail = failureProbability(returns, freq, targetSharpeRatio)
    println("Probability strategy will fail: ", probabilityFail)
    return probabilityFail
end
