import UIKit


class MEGARecordView: UIView {
    
    var view: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var volumeIcon: UIImageView!
    
    
    // MARK: - init
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: 180, height: 180))
        view = loadViewFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        view = loadViewFromNib()
    }
    
    func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName(), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        view.frame = bounds
        addSubview(view)
        if #available(iOS 13, *) {
            view.backgroundColor = UIColor.clear
            let effectView = UIVisualEffectView.init(frame: bounds)
            effectView.effect = UIBlurEffect.init(style:.systemChromeMaterialDark)
            addSubview(effectView)
            sendSubviewToBack(effectView)
        } else {
            view.backgroundColor = #colorLiteral(red: 0.1450980392, green: 0.1450980392, blue: 0.1450980392, alpha: 0.7764875856)
        }
        layer.cornerRadius = 8
        layer.masksToBounds = true
        return view
    }
    
    @objc var currentVolume: Float = 0 {
        didSet {
            print("audio\(currentVolume)")
            if currentVolume < 1/7 {
                volumeIcon.image = UIImage.init(named: "feedbackBars")
            } else if currentVolume < 2/7 {
                volumeIcon.image = UIImage.init(named: "feedbackBars1")
            } else if currentVolume < 3/7 {
                volumeIcon.image = UIImage.init(named: "feedbackBars2")
            } else if currentVolume < 4/7 {
                volumeIcon.image = UIImage.init(named: "feedbackBars3")
            } else if currentVolume < 5/7 {
                volumeIcon.image = UIImage.init(named: "feedbackBars4")
            } else if currentVolume < 6/7 {
                volumeIcon.image = UIImage.init(named: "feedbackBars5")
            } else {
                volumeIcon.image = UIImage.init(named: "feedbackBars6")
            }
            
        }
    }
    
    // MARK: - Private
    fileprivate func nibName() -> String {
        return String(describing: type(of: self))
    }
}

