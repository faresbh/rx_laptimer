
//
//  ViewController.swift
//  rx_laptimer
//
//  Created by Marin Todorov on 2/15/16.
//  Copyright © 2016 Underplot ltd. All rights reserved.
//
import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
  
  @IBOutlet weak var lblChrono: UILabel!
  @IBOutlet weak var btnLap: UIButton!
  @IBOutlet weak var tableView: UITableView!
  
  @IBOutlet weak var btnPlay: UIButton!
  @IBOutlet weak var btnStop: UIButton!
  
  let tableHeaderView = UILabel()
  
  let bag = DisposeBag()
  var timer: Observable<Int>!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableHeaderView.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
    
    let isRunning = Observable
      .merge([btnPlay.rx.tap.map({ return true }), btnStop.rx.tap.map({ return false })])
      .startWith(false)
        .share()
    
    isRunning
      .subscribe(onNext: {
        print($0)
      })
        .disposed(by: bag)
    
    let isntRunning = isRunning
      .map({running -> Bool in
        print(running)
        return !running
      })
        .share(replay: 1)
    
    isRunning
        .bind(to: btnStop.rx.isEnabled)
        .disposed(by: bag)
    
    isntRunning
        .bind(to: btnLap.rx.isHidden)
        .disposed(by: bag)
    
    isntRunning
        .bind(to: btnPlay.rx.isEnabled)
        .disposed(by: bag)
    
    //create the timer
    timer = Observable<Int>
        .interval(RxTimeInterval.milliseconds(1), scheduler: MainScheduler.instance)
      .withLatestFrom(isRunning, resultSelector: {_, running in running})
      .filter({running in running})
      .scan(0, accumulator: {(acc, _) in
        return acc+1
      })
      .startWith(0)
        .share()
    
    timer
      .subscribe { (msecs) in
        print("\(msecs)00ms")
      }
    .disposed(by: bag)
    
    //wire the chrono
    timer.map(stringFromTimeInterval)
        .bind(to: lblChrono.rx.text)
        .disposed(by: bag)
    
    let lapsSequence = timer
      .sample(btnLap.rx.tap)
      .map(stringFromTimeInterval)
      .scan([String](), accumulator: { lapTimes, newTime in
        return lapTimes + [newTime]
      })
        .share()
    
    lapsSequence
        .bind(to: tableView.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)) { (row, element, cell) in
        cell.textLabel?.text = "\(row+1)) \(element)"
      }
    .disposed(by: bag)
    
    //set table delegate
    tableView
      .rx.setDelegate(self)
        .disposed(by: bag)
    
    //update the table header
    lapsSequence.map({ laps -> String in
      return "\t\(laps.count) laps"
    })
      .startWith("\tno laps")
        .bind(to: tableHeaderView.rx.text)
        .disposed(by: bag)
    
  }
}

extension ViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    return tableHeaderView
  }
}

func stringFromTimeInterval(_ ms: NSInteger) -> String {
  return String(format: "%0.2d:%0.2d.%0.1d",
                arguments: [(ms / 600) % 600, (ms % 600 ) / 10, ms % 10])
}
