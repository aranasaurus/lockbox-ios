/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Quick
import Nimble
import RxTest
import RxSwift
import RxCocoa

@testable import Lockbox

class SettingsViewSpec: QuickSpec {
    class FakeSettingsPresenter: SettingsPresenter {
        var onViewReadyCalled = false
        var onDoneActionDispatched = false
        var switchChangedCalled = false
        var settingCellStub: TestableObserver<SettingRouteAction?>!

        override func onViewReady() {
            onViewReadyCalled = true
        }

        override func switchChanged(row: Int, isOn: Bool) {
            switchChangedCalled = true
        }

        override var onDone: AnyObserver<Void> {
            return Binder(self) { target, _ in
                target.onDoneActionDispatched = true
            }.asObserver()
        }

        override var onSettingCellTapped: AnyObserver<SettingRouteAction?> {
            return self.settingCellStub.asObserver()
        }
    }

    private var presenter: FakeSettingsPresenter!
    private var scheduler = TestScheduler(initialClock: 0)
    var subject: SettingsView!

    override func spec() {
        describe("SettingsView") {
            beforeEach {
                self.subject = SettingsView()
                self.presenter = FakeSettingsPresenter(view: self.subject)
                self.presenter.settingCellStub = self.scheduler.createObserver(SettingRouteAction?.self)
                self.subject.presenter = self.presenter

                self.subject.viewWillAppear(false)
                self.subject.viewDidLoad()
            }

            it("informs the presenter") {
                expect(self.presenter.onViewReadyCalled).to(beTrue())
            }

            describe("tableview datasource configuration") {
                let configDriver = PublishSubject<[SettingSectionModel]>()
                let sectionModels = [
                    SettingSectionModel(model: 0, items: [
                        SettingCellConfiguration(text: "Account", routeAction: SettingRouteAction.account),
                        SettingCellConfiguration(text: "FAQ", routeAction: SettingRouteAction.faq)
                    ]),
                    SettingSectionModel(model: 1, items: [
                        SwitchSettingCellConfiguration(text: "Enable in browser", routeAction: nil, isOn: true)
                    ])
                ]

                sectionModels[0].items[1].detailText = "FAQ Detail"

                beforeEach {
                    self.subject.bind(items: configDriver.asDriver(onErrorJustReturn: []))
                    configDriver.onNext(sectionModels)

                    let cell = self.subject.tableView.cellForRow(at: IndexPath(item: 0, section: 1))
                    let switchControl = cell?.accessoryView as? UISwitch
                    switchControl?.sendActions(for: .valueChanged)
                }

                it("configures table view based on model") {
                    expect(self.subject.tableView.numberOfSections).to(equal(2))
                    expect(self.subject.tableView.numberOfRows(inSection: 0)).to(equal(2))
                    expect(self.subject.tableView.numberOfRows(inSection: 1)).to(equal(1))
                }

                it("calls presenter when switch is flipped") {
                    expect(self.presenter.switchChangedCalled).to(beTrue())
                }

                it("sets detail text") {
                    expect(self.subject.tableView.cellForRow(at: IndexPath(item: 1, section: 0))?.detailTextLabel?.text).to(equal("FAQ Detail"))
                }
            }

            describe("tableview delegate configuration") {
                let configDriver = PublishSubject<[SettingSectionModel]>()
                let sectionModels = [
                    SettingSectionModel(model: 0, items: [
                        SettingCellConfiguration(text: "Account", routeAction: SettingRouteAction.account),
                        SettingCellConfiguration(text: "FAQ", routeAction: SettingRouteAction.faq)
                    ]),
                    SettingSectionModel(model: 1, items: [
                        SwitchSettingCellConfiguration(text: "Enable in browser", routeAction: nil, isOn: true)
                    ])
                ]

                beforeEach {
                    self.subject.bind(items: configDriver.asDriver(onErrorJustReturn: []))
                    configDriver.onNext(sectionModels)
                }

                describe("onCellTapped") {
                    beforeEach {
                        self.subject.tableView.delegate!.tableView!(self.subject.tableView, didSelectRowAt: [0, 0])
                    }

                    it("tells the presenter with the appropriate action") {
                        expect(self.presenter.settingCellStub.events.first!.value.element!).to(equal(SettingRouteAction.account))
                    }
                }
            }
        }
    }
}