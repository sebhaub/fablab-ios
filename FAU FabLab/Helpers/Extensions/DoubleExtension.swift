extension Double {
    var digitsAfterComma: Int {
        let s : String = String(stringInterpolationSegment: self)
        let substring = s.substringFromIndex(find(s, ".")!.successor())
        if substring == "0" {
            return 0
        }
        return count(substring) as Int
    }
    
    func roundDown(digitsAfterComma: Int) -> Double {
        let p : Double = pow(10, Double(digitsAfterComma))
        return Double(floor(p*self)/p)
    }
    
    func roundUpToRounding(rounding: Double) -> Double {
        return (Double(Int(self/rounding) + 1) * rounding)
    }
}