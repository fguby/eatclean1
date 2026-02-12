#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "apple" asset catalog image resource.
static NSString * const ACImageNameApple AC_SWIFT_PRIVATE = @"apple";

/// The "dingyue" asset catalog image resource.
static NSString * const ACImageNameDingyue AC_SWIFT_PRIVATE = @"dingyue";

/// The "fantuan_duanlian" asset catalog image resource.
static NSString * const ACImageNameFantuanDuanlian AC_SWIFT_PRIVATE = @"fantuan_duanlian";

/// The "fantuan_water" asset catalog image resource.
static NSString * const ACImageNameFantuanWater AC_SWIFT_PRIVATE = @"fantuan_water";

/// The "first" asset catalog image resource.
static NSString * const ACImageNameFirst AC_SWIFT_PRIVATE = @"first";

/// The "login_card_title" asset catalog image resource.
static NSString * const ACImageNameLoginCardTitle AC_SWIFT_PRIVATE = @"login_card_title";

/// The "onboarding_hero" asset catalog image resource.
static NSString * const ACImageNameOnboardingHero AC_SWIFT_PRIVATE = @"onboarding_hero";

/// The "riceball_boy" asset catalog image resource.
static NSString * const ACImageNameRiceballBoy AC_SWIFT_PRIVATE = @"riceball_boy";

/// The "riceball_camera" asset catalog image resource.
static NSString * const ACImageNameRiceballCamera AC_SWIFT_PRIVATE = @"riceball_camera";

/// The "riceball_eat" asset catalog image resource.
static NSString * const ACImageNameRiceballEat AC_SWIFT_PRIVATE = @"riceball_eat";

/// The "riceball_girl" asset catalog image resource.
static NSString * const ACImageNameRiceballGirl AC_SWIFT_PRIVATE = @"riceball_girl";

/// The "riceball_meditate" asset catalog image resource.
static NSString * const ACImageNameRiceballMeditate AC_SWIFT_PRIVATE = @"riceball_meditate";

/// The "riceball_run" asset catalog image resource.
static NSString * const ACImageNameRiceballRun AC_SWIFT_PRIVATE = @"riceball_run";

/// The "slogan" asset catalog image resource.
static NSString * const ACImageNameSlogan AC_SWIFT_PRIVATE = @"slogan";

/// The "vip" asset catalog image resource.
static NSString * const ACImageNameVip AC_SWIFT_PRIVATE = @"vip";

#undef AC_SWIFT_PRIVATE
