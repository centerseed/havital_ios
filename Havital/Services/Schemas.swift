//
//  schemas.swift
//  Havital
//
//  Created by 吳柏宗 on 2024/12/28.
//

import GoogleGenerativeAI
let trainingPlanSchema = Schema(
    type: .object,
    description: "Training schedule for the week",
    properties: [
        "purpose": Schema(
            type: .string,
            description: "The purpose of the week's training",
            nullable: false
        ),
        "tips": Schema(
            type: .string,
            description: "Tips for the training",
            nullable: false
        ),
        "days": Schema(
            type: .array,
            description: "List of training days",
            items: Schema(
                type: .object,
                properties: [
                    "target": Schema(
                        type: .string,
                        description: "The target activity for the day",
                        nullable: false
                    ),
                    "tips": Schema(
                        type: .string,
                        description: "The tips for the day",
                        nullable: false
                    ),
                    "is_training_day": Schema(
                        type: .boolean,
                        description: "Is training day or not",
                        nullable: false
                    ),
                    "training_items": Schema(
                        type: .array,
                        description: "List of training items for the day",
                        items: Schema(
                            type: .object,
                            properties: [
                                "name": Schema(
                                    type: .string,
                                    description: "Name of the training item",
                                    nullable: false
                                ),
                                "duration_minutes": Schema(
                                    type: .integer,
                                    description: "Duration of the training in minutes",
                                    nullable: false
                                ),
                                "goals": Schema(
                                    type: .object,
                                    description: "Goals for the training item",
                                    nullable: true, properties: [
                                        "times": Schema(
                                            type: .integer,
                                            description: "Number of times to perform the activity",
                                            nullable: true
                                        ),
                                        "heart_rate": Schema(
                                            type: .integer,
                                            description: "Target heart rate during the activity",
                                            nullable: true
                                        ),
                                        "pace": Schema(
                                            type: .integer,
                                            description: "Minite:seconds/1 km",
                                            nullable: true
                                        )
                                    ]
                                )
                            ],
                            requiredProperties: ["name"]
                        )
                    )
                ],
                requiredProperties: ["target", "training_items"]
            )
        )
    ],
    requiredProperties: ["purpose", "tips", "days"]
)

let summarySchema = Schema(
    type: .object,
    description: "Weekly training summary and analysis",
    properties: [
        "further_suggestion": Schema(
            type: .string,
            description: "Suggestions for future training",
            nullable: false
        ),
        "summary": Schema(
            type: .string,
            description: "Overall summary of the week's training performance",
            nullable: false
        ),
        "training_analysis": Schema(
            type: .string,
            description: "Detailed analysis of individual training sessions",
            nullable: false
        )
    ],
    requiredProperties: ["further_suggestion", "summary", "training_analysis"]
)

import Foundation

let trainingOverviewSchema = Schema(
    type: .object,
    description: "An overview of the training plan",
    properties: [
        "training_plan_name": Schema(
            type: .string,
            description: "The name of the training plan",
            nullable: false
        ),
        "training_plan_overview": Schema(
            type: .string,
            description: "An overview of the training plan",
            nullable: false
        ),
        "target_evaluate": Schema(
            type: .string,
            description: "The target evaluation for the training plan",
            nullable: false
        ),
        "training_hightlight": Schema(
            type: .string,
            description: "The highlights of the training plan",
            nullable: false
        ),
        "training_stage_discription": Schema(
            type: .array,
            description: "List of training stages",
            items: Schema(
                type: .object,
                description: "A single stage of the training plan",
                properties: [
                    "week_start": Schema(
                        type: .integer,
                        description: "The starting week of the training stage",
                        nullable: false
                    ),
                    "week_end": Schema(
                        type: .integer,
                        description: "The ending week of the training stage",
                        nullable: false
                    ),
                    "stage_name": Schema(
                        type: .string,
                        description: "The name of the training stage",
                        nullable: false
                    ),
                    "stage_discroption": Schema(
                        type: .string,
                        description: "The description of the training stage",
                        nullable: false
                    )
                ],
                requiredProperties: ["week_start", "week_end", "stage_name", "stage_discroption"]
            )
        ),
        "user_information": Schema(
            type: .object,
            description: "Information about the user",
            properties: [
                "workout_days": Schema(
                    type: .integer,
                    description: "Workout days in a week",
                    nullable: false
                ),
                "aerobics_level": Schema(
                    type: .string,
                    description: "The user's aerobics level",
                    nullable: true
                ),
                "strength_level": Schema(
                    type: .integer,
                    description: "The user's strength level",
                    nullable: true
                ),
                "age": Schema(
                    type: .string,
                    description: "The user's age",
                    nullable: false
                ),
                "preferred_workout": Schema(
                    type: .integer,
                    description: "The user's preferred workout type",
                    nullable: true
                ),
                "current_distance": Schema(
                    type: .integer,
                    description: "The user's current running distance",
                    nullable: true
                ),
                "current_pace": Schema(
                    type: .integer,
                    description: "The user's current pace, seconds/km",
                    nullable: true
                ),
                "target_distance": Schema(
                    type: .integer,
                    description: "The user's current running distance",
                    nullable: true
                ),
                "target_pace": Schema(
                    type: .integer,
                    description: "The user's current pace, seconds/km",
                    nullable: true
                )
            ],
            requiredProperties: ["aerobics_level", "strength_level", "age", "preferred_workout"]
        ),
        "total_weeks": Schema(
            type: .integer,
            description: "The total number of weeks in the training plan",
            nullable: false
        )
    ],
    requiredProperties: [
        "training_plan_name",
        "training_plan_overview",
        "target_evaluate",
        "training_hightlight",
        "training_stage_discription",
        "user_information",
        "total_weeks"
    ]
)
