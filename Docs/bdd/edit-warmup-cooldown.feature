# Version: 1.0
# Date: 2026-03-14
# Feature: Editable Warmup & Cooldown for Training Sessions

Feature: 訓練課表暖跑與緩和跑編輯
  As a runner using Paceriz
  I want to edit the warmup and cooldown segments of my training sessions
  So that I can customize my warm-up and cool-down to match my needs

  Background:
    Given I have a V2 training plan with weekly schedule
    And my VDOT is calculated

  @ac1
  Scenario: Warmup and cooldown are preserved when entering edit mode
    Given a training day has warmup "2km @ 6:30" and cooldown "1km @ 6:30"
    When I open the weekly schedule editor
    Then the warmup and cooldown data should be visible on the training day

  @ac2
  Scenario: Warmup and cooldown are preserved after saving edits
    Given a training day has warmup and cooldown segments
    When I edit the training day and save
    Then the warmup and cooldown data should be sent to the API
    And the saved plan should contain the original warmup and cooldown

  @ac3
  Scenario: Warmup and cooldown are preserved when reordering days
    Given day 2 has warmup "2km" and cooldown "1km"
    When I drag day 2 to position 5
    Then the moved day should still have warmup "2km" and cooldown "1km"

  @ac4
  Scenario: Editing warmup distance for intensity training
    Given I open the detail editor for an interval training day
    When I adjust the warmup distance to 3km
    Then the warmup pace should be auto-calculated based on recovery zone
    And the estimated warmup duration should update accordingly

  @ac5
  Scenario: Editing cooldown distance for intensity training
    Given I open the detail editor for a tempo training day
    When I adjust the cooldown distance to 2km
    Then the cooldown pace should be auto-calculated based on recovery zone
    And the estimated cooldown duration should update accordingly

  @ac6
  Scenario: Default warmup and cooldown for new intensity training
    Given I change a rest day to interval training
    Then a default warmup should be created with recovery pace from VDOT
    And a default cooldown should be created with recovery pace from VDOT

  @ac7
  Scenario: No warmup/cooldown for easy and recovery runs
    Given I open the detail editor for an easy run day
    Then no warmup or cooldown editor should be shown

  @ac8
  Scenario: Warmup and cooldown show in daily card summary
    Given a training day has warmup "2km" and cooldown "1km" with main interval "4x800m"
    When I view the daily card in edit mode
    Then I should see the warmup and cooldown info alongside the interval summary
