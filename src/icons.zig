const std = @import("std");
const p = @import("global_playdate.zig");

var iconTable: *p.LCDBitmapTable = undefined;
pub const size = 22;

pub fn init() void {
    iconTable = p.playdate.graphics.loadBitmapTable("images/memory", null) orelse @panic("Could not load icons");
}

pub fn get(icon: Icon) *p.LCDBitmap {
    return p.playdate.graphics.getTableBitmap(iconTable, @intFromEnum(icon)) orelse @panic("Could not get icon bitmap");
}

pub const Icon = enum(c_int) {
    accountBox = 0,
    account = 1,
    alertBoxFill = 2,
    alertBox = 3,
    alertCircleFill = 4,
    alertCircle = 5,
    alertHexagonFill = 6,
    alertHexagon = 7,
    alertOctagon = 8,
    alertRhombusFill = 9,
    alertRhombus = 10,
    alert = 11,
    alignHorizontalCenter = 12,
    alignHorizontalDistribute = 13,
    alignHorizontalLeft = 14,
    alignHorizontalRight = 15,
    alignVerticalBottom = 16,
    alignVerticalCenter = 17,
    alignVerticalDistribute = 18,
    alignVerticalTop = 19,
    alphaAFill = 20,
    alphaA = 21,
    alphaBFill = 22,
    alphaB = 23,
    alphaCFill = 24,
    alphaC = 25,
    alphaDFill = 26,
    alphaD = 27,
    alphaEFill = 28,
    alphaE = 29,
    alphaFFill = 30,
    alphaF = 31,
    alphaGFill = 32,
    alphaG = 33,
    alphaHFill = 34,
    alphaH = 35,
    alphaIFill = 36,
    alphaI = 37,
    alphaJFill = 38,
    alphaJ = 39,
    alphaKFill = 40,
    alphaK = 41,
    alphaLFill = 42,
    alphaL = 43,
    alphaMFill = 44,
    alphaM = 45,
    alphaNFill = 46,
    alphaN = 47,
    alphaOFill = 48,
    alphaO = 49,
    alphaPFill = 50,
    alphaP = 51,
    alphaQFill = 52,
    alphaQ = 53,
    alphaRFill = 54,
    alphaR = 55,
    alphaSFill = 56,
    alphaS = 57,
    alphaTFill = 58,
    alphaT = 59,
    alphaUFill = 60,
    alphaU = 61,
    alphaVFill = 62,
    alphaV = 63,
    alphaWFill = 64,
    alphaW = 65,
    alphaXFill = 66,
    alphaX = 67,
    alphaYFill = 68,
    alphaY = 69,
    alphaZFill = 70,
    alphaZ = 71,
    anvil = 72,
    applicationCode = 73,
    application = 74,
    appsBoxFill = 75,
    appsBox = 76,
    apps = 77,
    archive = 78,
    arrowBottomLeftCircle = 79,
    arrowBottomLeft = 80,
    arrowBottomRightCircle = 81,
    arrowBottomRight = 82,
    arrowDownBold = 83,
    arrowDownBox = 84,
    arrowDownCircle = 85,
    arrowDownLeftBox = 86,
    arrowDownLeft = 87,
    arrowDownRightBox = 88,
    arrowDownRight = 89,
    arrowDown = 90,
    arrowLeftBold = 91,
    arrowLeftBox = 92,
    arrowLeftCircle = 93,
    arrowLeftDown = 94,
    arrowLeftRight = 95,
    arrowLeftUp = 96,
    arrowLeft = 97,
    arrowRightBold = 98,
    arrowRightBox = 99,
    arrowRightCircle = 100,
    arrowRightDown = 101,
    arrowRightUp = 102,
    arrowRight = 103,
    arrowTopLeftCircle = 104,
    arrowTopLeft = 105,
    arrowTopRightCircle = 106,
    arrowTopRight = 107,
    arrowUpBold = 108,
    arrowUpBox = 109,
    arrowUpCircle = 110,
    arrowUpDown = 111,
    arrowUpLeftBox = 112,
    arrowUpLeft = 113,
    arrowUpRightBox = 114,
    arrowUpRight = 115,
    arrowUp = 116,
    arrow = 117,
    aspectRatio = 118,
    axe = 119,
    bagPersonalFill = 120,
    bagPersonal = 121,
    bank = 122,
    barcode = 123,
    battery0 = 124,
    battery100 = 125,
    battery25 = 126,
    battery50 = 127,
    battery75 = 128,
    battleAxe = 129,
    beer = 130,
    bell = 131,
    blood = 132,
    book = 133,
    bookmark = 134,
    borderBottomLeftRight = 135,
    borderBottomLeft = 136,
    borderBottomRight = 137,
    borderBottom = 138,
    borderInside = 139,
    borderLeftRight = 140,
    borderLeft = 141,
    borderNone = 142,
    borderOutside = 143,
    borderRight = 144,
    borderTopBottom = 145,
    borderTopLeftBottom = 146,
    borderTopLeftRight = 147,
    borderTopLeft = 148,
    borderTopRightBottom = 149,
    borderTopRight = 150,
    borderTop = 151,
    bowArrow = 152,
    bow = 153,
    boxLightDashedDownLeft = 154,
    boxLightDashedDownRight = 155,
    boxLightDashedHorizontal = 156,
    boxLightDashedUpLeft = 157,
    boxLightDashedUpRight = 158,
    boxLightDashedVerticalHorizontal = 159,
    boxLightDashedVertical = 160,
    boxLightDoubleDownLeft = 161,
    boxLightDoubleDownRight = 162,
    boxLightDoubleHorizontalDown = 163,
    boxLightDoubleHorizontalLightDown = 164,
    boxLightDoubleHorizontalLightUp = 165,
    boxLightDoubleHorizontalUp = 166,
    boxLightDoubleHorizontal = 167,
    boxLightDoubleRoundDownLeft = 168,
    boxLightDoubleRoundDownRight = 169,
    boxLightDoubleRoundUpLeft = 170,
    boxLightDoubleRoundUpRight = 171,
    boxLightDoubleUpLeft = 172,
    boxLightDoubleUpRight = 173,
    boxLightDoubleVerticalHorizontal = 174,
    boxLightDoubleVerticalLeft = 175,
    boxLightDoubleVerticalLightLeft = 176,
    boxLightDoubleVerticalLightRight = 177,
    boxLightDoubleVerticalRight = 178,
    boxLightDoubleVertical = 179,
    boxLightDownLeftCircle = 180,
    boxLightDownLeftStippleInner = 181,
    boxLightDownLeftStippleOuter = 182,
    boxLightDownLeftStipple = 183,
    boxLightDownLeft = 184,
    boxLightDownRightCircle = 185,
    boxLightDownRightStippleInner = 186,
    boxLightDownRightStippleOuter = 187,
    boxLightDownRightStipple = 188,
    boxLightDownRight = 189,
    boxLightFoldDownLeft = 190,
    boxLightFoldDownRight = 191,
    boxLightFoldUpLeft = 192,
    boxLightFoldUpRight = 193,
    boxLightHorizontalCircle = 194,
    boxLightHorizontalDownStippleDownLeft = 195,
    boxLightHorizontalDownStippleDownRight = 196,
    boxLightHorizontalDownStippleDown = 197,
    boxLightHorizontalDownStipple = 198,
    boxLightHorizontalDown = 199,
    boxLightHorizontalMenuDown = 200,
    boxLightHorizontalMenuLeft = 201,
    boxLightHorizontalMenuRight = 202,
    boxLightHorizontalMenuUp = 203,
    boxLightHorizontalStippleDown = 204,
    boxLightHorizontalStippleUp = 205,
    boxLightHorizontalStipple = 206,
    boxLightHorizontalUpStippleDown = 207,
    boxLightHorizontalUpStippleUpLeft = 208,
    boxLightHorizontalUpStippleUpRight = 209,
    boxLightHorizontalUpStippleUp = 210,
    boxLightHorizontalUpStipple = 211,
    boxLightHorizontalUp = 212,
    boxLightHorizontal = 213,
    boxLightRoundDownLeftStippleInner = 214,
    boxLightRoundDownLeftStippleOuter = 215,
    boxLightRoundDownLeftStipple = 216,
    boxLightRoundDownLeft = 217,
    boxLightRoundDownRightStippleInner = 218,
    boxLightRoundDownRightStippleOuter = 219,
    boxLightRoundDownRightStipple = 220,
    boxLightRoundDownRight = 221,
    boxLightRoundUpLeftStippleInner = 222,
    boxLightRoundUpLeftStippleOuter = 223,
    boxLightRoundUpLeftStipple = 224,
    boxLightRoundUpLeft = 225,
    boxLightRoundUpRightStippleInner = 226,
    boxLightRoundUpRightStippleOuter = 227,
    boxLightRoundUpRightStipple = 228,
    boxLightRoundUpRight = 229,
    boxLightUpLeftCircle = 230,
    boxLightUpLeftStippleInner = 231,
    boxLightUpLeftStippleOuter = 232,
    boxLightUpLeftStipple = 233,
    boxLightUpLeft = 234,
    boxLightUpRightCircle = 235,
    boxLightUpRightStippleInner = 236,
    boxLightUpRightStippleOuter = 237,
    boxLightUpRightStipple = 238,
    boxLightUpRight = 239,
    boxLightVerticalCircle = 240,
    boxLightVerticalHorizontalStippleDownLeft = 241,
    boxLightVerticalHorizontalStippleDownRight = 242,
    boxLightVerticalHorizontalStippleDown = 243,
    boxLightVerticalHorizontalStippleLeftDownRight = 244,
    boxLightVerticalHorizontalStippleLeftUpRight = 245,
    boxLightVerticalHorizontalStippleLeft = 246,
    boxLightVerticalHorizontalStippleRightDownLeft = 247,
    boxLightVerticalHorizontalStippleRightUpLeft = 248,
    boxLightVerticalHorizontalStippleRight = 249,
    boxLightVerticalHorizontalStippleUpLeft = 250,
    boxLightVerticalHorizontalStippleUpRight = 251,
    boxLightVerticalHorizontalStippleUp = 252,
    boxLightVerticalHorizontalStipple = 253,
    boxLightVerticalHorizontal = 254,
    boxLightVerticalLeftStippleDownLeft = 255,
    boxLightVerticalLeftStippleLeft = 256,
    boxLightVerticalLeftStippleUpLeft = 257,
    boxLightVerticalLeftStipple = 258,
    boxLightVerticalLeft = 259,
    boxLightVerticalMenuDown = 260,
    boxLightVerticalMenuLeft = 261,
    boxLightVerticalMenuRight = 262,
    boxLightVerticalMenuUp = 263,
    boxLightVerticalRightStippleDownRight = 264,
    boxLightVerticalRightStippleLeft = 265,
    boxLightVerticalRightStippleRight = 266,
    boxLightVerticalRightStippleUpRight = 267,
    boxLightVerticalRightStipple = 268,
    boxLightVerticalRight = 269,
    boxLightVerticalStippleLeft = 270,
    boxLightVerticalStippleRight = 271,
    boxLightVerticalStipple = 272,
    boxLightVertical = 273,
    boxOuterLightAll = 274,
    boxOuterLightDashedAll = 275,
    boxOuterLightDashedDownLeftRight = 276,
    boxOuterLightDashedDownLeft = 277,
    boxOuterLightDashedDownRight = 278,
    boxOuterLightDashedDown = 279,
    boxOuterLightDashedFoldDownLeft = 280,
    boxOuterLightDashedFoldDownRight = 281,
    boxOuterLightDashedFoldUpLeft = 282,
    boxOuterLightDashedFoldUpRight = 283,
    boxOuterLightDashedLeftRight = 284,
    boxOuterLightDashedLeft = 285,
    boxOuterLightDashedRight = 286,
    boxOuterLightDashedUpDownLeft = 287,
    boxOuterLightDashedUpDownRight = 288,
    boxOuterLightDashedUpDown = 289,
    boxOuterLightDashedUpLeftRight = 290,
    boxOuterLightDashedUpLeft = 291,
    boxOuterLightDashedUpRight = 292,
    boxOuterLightDashedUp = 293,
    boxOuterLightDownLeftRight = 294,
    boxOuterLightDownLeftStipple = 295,
    boxOuterLightDownLeft = 296,
    boxOuterLightDownRightStipple = 297,
    boxOuterLightDownRight = 298,
    boxOuterLightDownStipple = 299,
    boxOuterLightDownVerticalStippleLeft = 300,
    boxOuterLightDownVerticalStippleRight = 301,
    boxOuterLightDownVerticalStipple = 302,
    boxOuterLightDown = 303,
    boxOuterLightLeftHorizontalStippleDown = 304,
    boxOuterLightLeftHorizontalStippleUp = 305,
    boxOuterLightLeftHorizontalStipple = 306,
    boxOuterLightLeftRightStipple = 307,
    boxOuterLightLeftRight = 308,
    boxOuterLightLeftStipple = 309,
    boxOuterLightLeft = 310,
    boxOuterLightRightHorizontalStippleDown = 311,
    boxOuterLightRightHorizontalStippleUp = 312,
    boxOuterLightRightHorizontalStipple = 313,
    boxOuterLightRightStipple = 314,
    boxOuterLightRight = 315,
    boxOuterLightRoundDownLeft = 316,
    boxOuterLightRoundDownRight = 317,
    boxOuterLightRoundUpLeft = 318,
    boxOuterLightRoundUpRight = 319,
    boxOuterLightUpDownLeft = 320,
    boxOuterLightUpDownRight = 321,
    boxOuterLightUpDownStipple = 322,
    boxOuterLightUpDown = 323,
    boxOuterLightUpLeftRight = 324,
    boxOuterLightUpLeftStipple = 325,
    boxOuterLightUpLeft = 326,
    boxOuterLightUpRightStipple = 327,
    boxOuterLightUpRight = 328,
    boxOuterLightUpStipple = 329,
    boxOuterLightUpVerticalStippleLeft = 330,
    boxOuterLightUpVerticalStippleRight = 331,
    boxOuterLightUpVerticalStipple = 332,
    boxOuterLightUp = 333,
    box = 334,
    briefcase = 335,
    broadcast = 336,
    bugFill = 337,
    bug = 338,
    calculator = 339,
    calendarImport = 340,
    calendarMonth = 341,
    calendar = 342,
    cancel = 343,
    cardText = 344,
    card = 345,
    cart = 346,
    cash = 347,
    cast = 348,
    castle = 349,
    chartBar = 350,
    chatProcessing = 351,
    chat = 352,
    check = 353,
    checkboxBlank = 354,
    checkboxCross = 355,
    checkboxIntermediateVariant = 356,
    checkboxIntermediate = 357,
    checkboxMarked = 358,
    checkerLarge = 359,
    checkerMedium = 360,
    checkerSmall = 361,
    checkerboard = 362,
    chestFill = 363,
    chest = 364,
    chevronDownCircle = 365,
    chevronDown = 366,
    chevronLeftCircle = 367,
    chevronLeft = 368,
    chevronRightCircle = 369,
    chevronRight = 370,
    chevronUpCircle = 371,
    chevronUp = 372,
    circle = 373,
    clipboard = 374,
    clockFill = 375,
    clock = 376,
    closeOutline = 377,
    close = 378,
    cloudDown = 379,
    cloudUp = 380,
    cloud = 381,
    coffee = 382,
    coinCopper = 383,
    coinElectrum = 384,
    coinGold = 385,
    coinPlatinum = 386,
    coinSilver = 387,
    commentText = 388,
    commentUser = 389,
    comment = 390,
    compassEastArrow = 391,
    compassNorthArrow = 392,
    compassNorthEast = 393,
    compassNorthWest = 394,
    compassSouthArrow = 395,
    compassSouthEast = 396,
    compassSouthWest = 397,
    compassWestArrow = 398,
    compass = 399,
    creditCard = 400,
    crossbow = 401,
    crown = 402,
    cubeUnfolded = 403,
    cube = 404,
    dagger = 405,
    database = 406,
    device = 407,
    diamond = 408,
    division = 409,
    doorBox = 410,
    doorOpen = 411,
    door = 412,
    dotHexagonFill = 413,
    dotHexagon = 414,
    dotOctagonFill = 415,
    dotOctagon = 416,
    download = 417,
    email = 418,
    eyeFill = 419,
    eye = 420,
    file = 421,
    fill = 422,
    filter = 423,
    fire = 424,
    flaskEmpty = 425,
    flaskRoundBottomEmpty = 426,
    flaskRoundBottom = 427,
    flask = 428,
    floppyDisk = 429,
    folderOpen = 430,
    folder = 431,
    formatAlignBottom = 432,
    formatAlignCenter = 433,
    formatAlignJustify = 434,
    formatAlignLeft = 435,
    formatAlignRight = 436,
    formatAlignTop = 437,
    formatBold = 438,
    formatFloatLeft = 439,
    formatFloatRight = 440,
    formatHorizontalAlignCenter = 441,
    formatItalic = 442,
    formatLineSpacing = 443,
    formatTextMultiline = 444,
    formatTextSingleLine = 445,
    formatText = 446,
    formatVerticalAlignCenter = 447,
    gamepadCenterFill = 448,
    gamepadCenter = 449,
    gamepadDownFill = 450,
    gamepadDownLeftFill = 451,
    gamepadDownLeft = 452,
    gamepadDownRightFill = 453,
    gamepadDownRight = 454,
    gamepadDown = 455,
    gamepadFill = 456,
    gamepadLeftFill = 457,
    gamepadLeft = 458,
    gamepadRightFill = 459,
    gamepadRight = 460,
    gamepadUpFill = 461,
    gamepadUpLeftFill = 462,
    gamepadUpLeft = 463,
    gamepadUpRightFill = 464,
    gamepadUpRight = 465,
    gamepadUp = 466,
    gamepad = 467,
    glaive = 468,
    glasses = 469,
    halberd = 470,
    heartBroken = 471,
    heart = 472,
    helpBoxFill = 473,
    helpBox = 474,
    help = 475,
    hexagon = 476,
    homeThatched = 477,
    image = 478,
    javalin = 479,
    journal = 480,
    key = 481,
    labelVariant = 482,
    label = 483,
    lance = 484,
    led = 485,
    lightbulb = 486,
    linen = 487,
    lockOpen = 488,
    lock = 489,
    login = 490,
    logout = 491,
    magnifyMinus = 492,
    magnifyPlus = 493,
    map = 494,
    menuBottomLeft = 495,
    menuBottomRight = 496,
    menuDownFill = 497,
    menuDown = 498,
    menuLeftFill = 499,
    menuLeftRight = 500,
    menuLeft = 501,
    menuRightFill = 502,
    menuRight = 503,
    menuTopLeft = 504,
    menuTopRight = 505,
    menuUpDown = 506,
    menuUpFill = 507,
    menuUp = 508,
    messageProcessing = 509,
    messageText = 510,
    messageUser = 511,
    message = 512,
    microphone = 513,
    minusBoxFill = 514,
    minusBox = 515,
    minusCircleFill = 516,
    minusCircle = 517,
    minus = 518,
    monitorImage = 519,
    monitor = 520,
    multiply = 521,
    musicNote = 522,
    necklace = 523,
    noteNailed = 524,
    note = 525,
    notebook = 526,
    notification = 527,
    number = 528,
    octagon = 529,
    paperclip = 530,
    pause = 531,
    peace = 532,
    pencil = 533,
    pickaxe = 534,
    pictogrammers = 535,
    pike = 536,
    play = 537,
    plusBoxFill = 538,
    plusBox = 539,
    plusCircleFill = 540,
    plusCircle = 541,
    plus = 542,
    poll = 543,
    pound = 544,
    quarterstaff = 545,
    radioboxMarked = 546,
    radiobox = 547,
    range = 548,
    relativeScale = 549,
    removeCircle = 550,
    ring = 551,
    rotateClockwise = 552,
    rotateCounterclockwise = 553,
    scimitar = 554,
    script = 555,
    search = 556,
    shield = 557,
    shovel = 558,
    skull = 559,
    sliderEnd = 560,
    sliderRight = 561,
    speaker = 562,
    spear = 563,
    stool = 564,
    stop = 565,
    sword = 566,
    tableTopDoorHorizontal = 567,
    tableTopDoorOneWayDown = 568,
    tableTopDoorOneWayLeft = 569,
    tableTopDoorOneWayRight = 570,
    tableTopDoorOneWayUp = 571,
    tableTopDoorSecretHorizontal = 572,
    tableTopDoorSecretVertical = 573,
    tableTopDoorVertical = 574,
    tableTopHorizontalRotateClockwise = 575,
    tableTopHorizontalRotateCounterclockwise = 576,
    tableTopHorizontalStairsAscendLeft = 577,
    tableTopHorizontalStairsAscendRight = 578,
    tableTopHorizontalStairsDescendDown = 579,
    tableTopHorizontalStairsDescendLeft = 580,
    tableTopHorizontalStairsDescendRight = 581,
    tableTopHorizontalStairsDescendUp = 582,
    tableTopSpiralStairsDown = 583,
    tableTopSpiralStairsLeft = 584,
    tableTopSpiralStairsRight = 585,
    tableTopSpiralStairsRoundDown = 586,
    tableTopSpiralStairsRoundLeft = 587,
    tableTopSpiralStairsRoundRight = 588,
    tableTopSpiralStairsRoundUp = 589,
    tableTopSpiralStairsUp = 590,
    tableTopStairsDown = 591,
    tableTopStairsLeft = 592,
    tableTopStairsRight = 593,
    tableTopStairsUp = 594,
    tableTopVerticalRotateClockwise = 595,
    tableTopVerticalRotateCounterclockwise = 596,
    tableTopVerticalStairsAscendDown = 597,
    tableTopVerticalStairsAscendUp = 598,
    tagText = 599,
    tag = 600,
    target = 601,
    tent = 602,
    terminal = 603,
    textBox = 604,
    textImage = 605,
    tileCautionHeavy = 606,
    tileCautionThin = 607,
    tileDiamondHex = 608,
    timeSand = 609,
    toggleSwitchOff = 610,
    toggleSwitchOn = 611,
    toolbox = 612,
    tooltipAboveAlert = 613,
    tooltipAboveHelp = 614,
    tooltipAboveText = 615,
    tooltipAbove = 616,
    tooltipBelowAlert = 617,
    tooltipBelowHelp = 618,
    tooltipBelowText = 619,
    tooltipBelow = 620,
    tooltipEndAlert = 621,
    tooltipEndHelp = 622,
    tooltipEndText = 623,
    tooltipEnd = 624,
    tooltipStartAlert = 625,
    tooltipStartHelp = 626,
    tooltipStartText = 627,
    tooltipStart = 628,
    torch = 629,
    toyBrick = 630,
    trash = 631,
    trident = 632,
    umbrella = 633,
    upload = 634,
    volumeHigh = 635,
    volumeLow = 636,
    volumeMedium = 637,
    volumeMute = 638,
    wallFill = 639,
    wallFrontDamaged = 640,
    wallFrontGate = 641,
    wallFront = 642,
    wall = 643,
    waterFill = 644,
    water = 645,
    weightFill = 646,
    weight = 647,
    well = 648,
    whip = 649,
    wind = 650,
};
