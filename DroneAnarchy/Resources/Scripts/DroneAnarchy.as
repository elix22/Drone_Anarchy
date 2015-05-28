#include "GameObjects.as"

enum GameState
{
	GS_INGAME = 101,
	GS_OUTGAME,
	GS_PAUSED
}

const int BULLET_COLLISION_LAYER = 1;
const int PLAYER_COLLISION_LAYER = 2;
const int DRONE_COLLISION_LAYER = 3;
const int FLOOR_COLLISION_LAYER = 5;
const int SCORE_ADDITION_RATE = 1;

const uint MAX_DRONE_COUNT = 15;

const float EASY_PHASE = 0;
const float MODERATE_PHASE = 60;
const float CRITICAL_PHASE = 120;
const float EASY_PHASE_RATE = 5;
const float MODERATE_PHASE_RATE = 3;
const float CRITICAL_PHASE_RATE = 1;
const float SCENE_TO_UI_SCALE = 1.6f;
const float SPRITE_UPDATE_TIME = 0.04f;

int playerScore_ = 0;

float spriteUpdateCounter_ = 0.0f;
float droneSpawnCounter_ = 0.0f;
float gamePhaseCounter_ = 0.0f;

bool onQuit_ = false;
bool playerDestroyed_ = false;

String optionsMessage_ = "<SPACE> To Replay | <ESC> To Quit";

GameState gameState_ = GS_OUTGAME;

Scene@ scene_;
Node@ cameraNode_;
Node@ playerNode_;

Viewport@ viewport_;
SoundSource@ backgroundMusicSource_;
ValueAnimation@ valAnim_;

Sprite@ radarScreenBase_;
Sprite@ healthFillSprite_;
Sprite@ targetSprite_;

Text@ enemyCounterText_;
Text@ playerScoreText_;
Text@ statusText_;
Text@ playerScoreMessageText_;
Text@ optionsInfoText_;





void Start()
{
	graphics.windowTitle = "Drone Anarchy";
	
	CreateDebugHud();
	
	
	CreateValueAnimation();
	CreateInterface();
	
	//This is to prevent the pause that occurs in loading a resource for the first time
	LoadBackgroundResources();
	
	CreateScene();
	CreateCameraAndLight();
	SubscribeToEvents();
	
	CreateAudioSystem();
	
	StartGame();
}


void StartGame()
{
	playerScoreMessageText_.text = "";
	optionsInfoText_.text = "";
	gamePhaseCounter_ = 0.0f;
	playerScore_ = 0;
	
	CreatePlayer();
	
	//The following two lines come into play when restarting the game
	healthFillSprite_.imageRect = IntRect(0, 0, 512, 64);
	UpdateHealthTexture(1);
	
	PlayBackgroundMusic("Resources/Sounds/cyber_dance.ogg");
	StartCounterToGame();
}


void CreateDebugHud()
{
	// Get default style
	XMLFile@ xmlFile = cache.GetResource("XMLFile", "UI/DefaultStyle.xml");
	if (xmlFile is null)
		return;
			
	// Create debug HUD
	DebugHud@ debugHud = engine.CreateDebugHud();
	debugHud.defaultStyle = xmlFile;
}


void CreateCameraAndLight()
{
	cameraNode_ = scene_.CreateChild();
	cameraNode_.CreateComponent("Camera");
	cameraNode_.Translate(Vector3(0,1.7,0));
	
	Node@ lightNode = cameraNode_.CreateChild("DirectionalLight");
    lightNode.direction = Vector3(0.6f, -1.0f, 0.8f);
    Light@ light = lightNode.CreateComponent("Light");
    light.lightType = LIGHT_DIRECTIONAL;	
	
	audio.listener = cameraNode_.CreateComponent("SoundListener");
	
	renderer.viewports[0] = Viewport(scene_, cameraNode_.GetComponent("Camera"));
}

void CreatePlayer()
{
	
	playerNode_ = scene_.CreateChild("PlayerNode");
	RigidBody@ playerBody  = playerNode_.CreateComponent("RigidBody");
	playerBody.SetCollisionLayerAndMask(PLAYER_COLLISION_LAYER, DRONE_COLLISION_LAYER);
	CollisionShape@ playerColShape = playerNode_.CreateComponent("CollisionShape");
	playerColShape.SetSphere(2);
	
	playerNode_.CreateScriptObject(scriptFile,"PlayerObject");
	
	playerDestroyed_ = false;

}

void CreateInterface()
{
	CreateHUD();
	CreateEnemyCounterUI();
	CreatePlayerScoreUI();
	CreateDisplayTexts();
}


void CreateHUD()
{
	Sprite@ hudSprite = ui.root.CreateChild("Sprite");
	
	hudSprite.texture = cache.GetResource("Texture2D", "Resources/Textures/hud.png");
	hudSprite.SetAlignment(HA_CENTER, VA_BOTTOM);
	hudSprite.SetSize(512, 256);
	hudSprite.SetHotSpot(256, 256);
	hudSprite.blendMode = BLEND_ALPHA;
	hudSprite.priority = 3;
	
	Sprite@ hudSpriteBG = ui.root.CreateChild("Sprite");
	hudSpriteBG.texture = cache.GetResource("Texture2D", "Resources/Textures/hud_bg.png");
	hudSpriteBG.SetAlignment(HA_CENTER, VA_BOTTOM);
	hudSpriteBG.SetSize(512, 256);
	hudSpriteBG.SetHotSpot(256, 256);
	hudSpriteBG.opacity = 0.6f;
	hudSpriteBG.blendMode = BLEND_ALPHA;
	hudSpriteBG.priority = -3;
	
	Sprite@ healthBaseSprite = ui.root.CreateChild("Sprite");
	healthBaseSprite.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bg.png");
	healthBaseSprite.SetAlignment(HA_CENTER, VA_BOTTOM);
	healthBaseSprite.SetSize(512,128);
	healthBaseSprite.SetHotSpot(256,64);
	healthBaseSprite.blendMode = BLEND_ALPHA;
	healthBaseSprite.priority = 1;
	healthBaseSprite.opacity = 0.9f;
	
	healthFillSprite_ = healthBaseSprite.CreateChild("Sprite");
	healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_green.png");
	healthFillSprite_.SetAlignment(HA_CENTER, VA_CENTER);
	healthFillSprite_.SetSize(256, 25);
	healthFillSprite_.SetHotSpot(128, 25);
	healthFillSprite_.imageRect = IntRect(0,0,512,64);
	healthFillSprite_.opacity = 0.5f;
	healthFillSprite_.blendMode = BLEND_ALPHA;
	
	radarScreenBase_ = ui.root.CreateChild("Sprite");
	radarScreenBase_.texture = cache.GetResource("Texture2D", "Resources/Textures/radar_screen_base_.png");
	radarScreenBase_.SetSize(128, 128);
	radarScreenBase_.SetAlignment(HA_CENTER, VA_BOTTOM);
	radarScreenBase_.SetHotSpot(64, 64);
	radarScreenBase_.position = Vector2(0, -99);
	radarScreenBase_.opacity = 0.9f;
	radarScreenBase_.priority = 2;
	radarScreenBase_.color = Color(0.0, 0.4, 0.3,0.7);
	
	
	Sprite@ radarScreen = ui.root.CreateChild("Sprite");
	radarScreen.texture = cache.GetResource("Texture2D", "Resources/Textures/radar_screen.png");
	radarScreen.SetSize(128, 128);
	radarScreen.SetAlignment(HA_CENTER, VA_BOTTOM);
	radarScreen.SetHotSpot(64, 64);
	radarScreen.position = Vector2(0, -99);
	radarScreen.blendMode = BLEND_ALPHA;
	radarScreen.priority = 4;
	
	targetSprite_ = ui.root.CreateChild("Sprite");
	targetSprite_.texture = cache.GetResource("Texture2D","Resources/Textures/target.png");
	targetSprite_.SetSize(70,70);
	targetSprite_.SetAlignment(HA_CENTER, VA_CENTER);
	targetSprite_.SetHotSpot(35,35);
	targetSprite_.blendMode = BLEND_ALPHA;
	targetSprite_.opacity = 0.6f;
	targetSprite_.visible = false;
	
}

void CreateEnemyCounterUI()
{
	enemyCounterText_ = ui.root.CreateChild("Text");
	enemyCounterText_.SetFont(cache.GetResource("Font", "Resources/Fonts/segment7standard.otf"),15);
	enemyCounterText_.SetAlignment(HA_CENTER, VA_BOTTOM);
	
	enemyCounterText_.color = Color(0.7f, 0.0f, 0.0f);
	enemyCounterText_.position = IntVector2(-140,-72);
	enemyCounterText_.priority = 1;
	
	enemyCounterText_.textEffect = TE_SHADOW;
}

void CreatePlayerScoreUI()
{
	playerScoreText_ = ui.root.CreateChild("Text");
	playerScoreText_.SetFont(cache.GetResource("Font", "Resources/Fonts/segment7standard.otf"),15);
	playerScoreText_.SetAlignment(HA_CENTER, VA_BOTTOM);
	
	playerScoreText_.color = Color(0.0f, 0.9f, 0.2f);
	playerScoreText_.position = IntVector2(140,-72);
	playerScoreText_.priority = 1;
	
	playerScoreText_.textEffect = TE_SHADOW;
	
}

void CreateDisplayTexts()
{

	statusText_ = ui.root.CreateChild("Text");
	statusText_.SetFont(cache.GetResource("Font", "Resources/Fonts/gtw.ttf"),70);
	statusText_.SetAlignment(HA_CENTER, VA_TOP);
	statusText_.color = Color(0.2f, 0.8f, 1.0f);
	statusText_.priority = 1;
	statusText_.textEffect = TE_SHADOW;

	playerScoreMessageText_ = ui.root.CreateChild("Text");
	playerScoreMessageText_.SetFont(cache.GetResource("Font", "Resources/Fonts/gtw.ttf"),50);
	playerScoreMessageText_.SetAlignment(HA_CENTER, VA_TOP);
	playerScoreMessageText_.position = IntVector2(0,150);
	playerScoreMessageText_.color = Color(0.2f, 0.8f, 1.0f);
	playerScoreMessageText_.textEffect = TE_SHADOW;
	
	
	optionsInfoText_ = ui.root.CreateChild("Text");
	optionsInfoText_.SetFont(cache.GetResource("Font", "Resources/Fonts/gtw.ttf"),20);
	optionsInfoText_.SetAlignment(HA_CENTER, VA_CENTER);
	optionsInfoText_.position = IntVector2(0,50);
	optionsInfoText_.color = Color(0.2f, 0.8f, 1.0f);
	optionsInfoText_.textEffect = TE_SHADOW;
}

void StartCounterToGame()
{
	ValueAnimation@ textAnimation = ValueAnimation();
		
	textAnimation.SetKeyFrame(0.0f, Variant("5"));
	textAnimation.SetKeyFrame(1.0f, Variant("4"));
	textAnimation.SetKeyFrame(2.0f, Variant("3"));
	textAnimation.SetKeyFrame(3.0f, Variant("2"));
	textAnimation.SetKeyFrame(4.0f, Variant("1"));
	textAnimation.SetKeyFrame(5.0f, Variant("PLAY"));
	textAnimation.SetKeyFrame(6.0f, Variant(""));
	
	//Trigger  CountFinished event at the end of the animation
	textAnimation.SetEventFrame(6.0f, "CountFinished");

	statusText_.SetAttributeAnimation("Text", textAnimation,WM_ONCE);
}

void CreateAudioSystem()
{
    audio.masterGain[SOUND_MASTER] = 0.75;
    audio.masterGain[SOUND_MUSIC] = 0.13;
	audio.masterGain[SOUND_EFFECT] = 0.5;
	
	Node@ backgroundMusicNode = scene_.CreateChild();
	backgroundMusicSource_ = backgroundMusicNode.CreateComponent("SoundSource");
    backgroundMusicSource_.soundType = SOUND_MUSIC;
	
}

void LoadBackgroundResources()
{
	cache.BackgroundLoadResource("Model","Resources/Models/drone_body.mdl");
	cache.BackgroundLoadResource("Model","Resources/Models/drone_arm.mdl");
	cache.BackgroundLoadResource("Animation","Resources/Models/open_arm.ani");
	cache.BackgroundLoadResource("Animation","Resources/Models/close_arm.ani");
	
	cache.BackgroundLoadResource("Texture2D", "Resources/Textures/explosion.png");
	
	cache.BackgroundLoadResource("ParticleEffect", "Resources/Particles/bullet_particle.xml");
	cache.BackgroundLoadResource("ParticleEffect", "Resources/Particles/explosion.xml");
	
	cache.BackgroundLoadResource("Material","Resources/Materials/drone_arm.xml");
	cache.BackgroundLoadResource("Material","Resources/Materials/drone_body.xml");
	cache.BackgroundLoadResource("Material", "Resources/Materials/bullet_particle.xml");
	cache.BackgroundLoadResource("Material", "Resources/Materials/explosion.xml");
	
	cache.BackgroundLoadResource("Texture2D", "Resources/Textures/drone_sprite.png");
	cache.BackgroundLoadResource("Texture2D", "Resources/Textures/health_bar_green.png");
	cache.BackgroundLoadResource("Texture2D", "Resources/Textures/health_bar_red.png");
	cache.BackgroundLoadResource("Texture2D", "Resources/Textures/health_bar_yellow.png");
	
	cache.BackgroundLoadResource("Sound", "Resources/Sounds/boom1.wav");
	
	
}


void CreateScene()
{
	scene_ = Scene();
	scene_.updateEnabled = false;
	
	scene_.CreateComponent("Octree");
	scene_.CreateComponent("PhysicsWorld");
	
	// Create a Zone component for ambient lighting & fog control
    Node@ zoneNode = scene_.CreateChild("Zone");
    Zone@ zone = zoneNode.CreateComponent("Zone");
    zone.boundingBox = BoundingBox(-1000.0f, 1000.0f);
    zone.ambientColor = Color(0.2f, 0.2f, 0.2f);
    zone.fogColor = Color(0.5f, 0.5f, 1.0f);
    zone.fogStart = 5.0f;
    zone.fogEnd = 300.0f;
	
	//Create a plane
	Node@ planeNode = scene_.CreateChild("Plane");
	StaticModel@ plane = planeNode.CreateComponent("StaticModel");
	
	plane.model = cache.GetResource("Model", "Resources/Models/floor.mdl");
	plane.material = cache.GetResource("Material", "Resources/Materials/floor.xml");

	
	//Add physics Components to the plane
	RigidBody@ planeBody = planeNode.CreateComponent("RigidBody");
	planeBody.SetCollisionLayerAndMask(FLOOR_COLLISION_LAYER, DRONE_COLLISION_LAYER | BULLET_COLLISION_LAYER);
	CollisionShape@ colShape = planeNode.CreateComponent("CollisionShape");
	colShape.SetTriangleMesh(cache.GetResource("Model", "Resources/Models/floor.mdl"));
	
}

void PlayBackgroundMusic(String musicName)
{
	Sound@ musicFile = cache.GetResource("Sound",musicName);
	
	if(musicFile is null)
		return;
		
    musicFile.looped = true;
    backgroundMusicSource_.Play(musicFile);
}


void CreateValueAnimation()
{
	valAnim_ = ValueAnimation();
	valAnim_.SetKeyFrame(0, Variant(Color(0.0, 0.4, 0.3, 0.7)));
	valAnim_.SetKeyFrame(0.3, Variant(Color(0.3,0.0,0.0)));
	valAnim_.SetKeyFrame(1, Variant(Color(0.0, 0.4, 0.3, 0.7)));
}

void SubscribeToEvents()
{
	SubscribeToEvent("KeyDown","HandleKeyDown");
	SubscribeToEvent("Update", "HandleUpdate");
	SubscribeToEvent("MouseMove", "HandleMouseMove");
	SubscribeToEvent("MouseButtonDown", "HandleMouseClick");
	SubscribeToEvent("PlayerHit","HandlePlayerHit");
	SubscribeToEvent("DroneDestroyed", "HandleDroneDestroyed");
	SubscribeToEvent("DroneHit", "HandleDroneHit");
	SubscribeToEvent("CountFinished", "HandleCountFinished");
	SubscribeToEvent(scene_.physicsWorld, "PhysicsPreStep", "HandleFixedUpdate");
	
}


void HandleKeyDown(StringHash eventType, VariantMap& eventData)
{
	int key = eventData["key"].GetInt();
	
	if(key == KEY_ESC)
		onQuit_ = true;
	else if(key == KEY_F2)
		debugHud.ToggleAll();
	else if(gameState_ == GS_OUTGAME)
	{
		HandleKeyOnOutGame(key);
	}
	else 
	{
		HandleKeyOnInGame(key);
	}
		
}

void PauseGame()
{
	scene_.updateEnabled = !scene_.updateEnabled;
	
	if(scene_.updateEnabled)
	{
		statusText_.text = "";
		gameState_ = GS_INGAME;
	}
	else
	{
		statusText_.text = "PAUSED";
		gameState_ = GS_PAUSED;
	}
	
	targetSprite_.visible = scene_.updateEnabled;
}

void HandleKeyOnOutGame(int key)
{
	if(key == KEY_SPACE)
	{
		StartGame();
	}
}

void HandleKeyOnInGame(int key)
{
	if(key == KEY_P)
	{
		PauseGame();
	}
}

void HandleUpdate(StringHash eventType, VariantMap& eventData)
{
	if(onQuit_)
	{
		engine.Exit();
	}
	else if(playerDestroyed_ && gameState_ == GS_INGAME)
	{
		InitiateGameOver();
	}
}

void InitiateGameOver()
{
	scene_.updateEnabled = false;
	gameState_ = GS_OUTGAME;
	
	CleanupScene();
	PlayBackgroundMusic("Resources/Sounds/Defeated.ogg");
	
	targetSprite_.visible = false;
	statusText_.text = "YOU FAILED";
	playerScoreMessageText_.text = "Score : " + String(playerScore_);
	optionsInfoText_.text = optionsMessage_ ;

}

void CleanupScene()
{
	//For each drone node in the scene delete the node sprite associated with it and also remove the node
	Array<Node@> droneNodes = scene_.GetChildrenWithScript("DroneObject",true);
	for(uint i=0; i < droneNodes.length ; i++)
	{
		Node@ droneNode = droneNodes[i];
		Sprite@ nodeSprite = droneNode.vars["Sprite"].GetPtr();
		nodeSprite.Remove();
		droneNode.Remove();
	}
	
	//Cleanup any bullet still remaining in the scene
	Array<Node@> bulletNodes = scene_.GetChildrenWithScript("BulletObject", true);
	for(uint i = 0; i < bulletNodes.length; i++)
	{
		bulletNodes[i].Remove();
	}
	
	//Cleanup any explosion still remaining in the scene
	Array<Node@> explosionNodes = scene_.GetChildrenWithScript("ExplosionObject", true);
	for(uint i = 0; i < explosionNodes.length; i++)
	{
		explosionNodes[i].Remove();
	}
	
	//Remove the player Node
	playerNode_.Remove();
	
	
	//Hide the enemy counter and player score texts
	enemyCounterText_.text = "";
	playerScoreText_.text = "";
	
	
}


void HandleMouseMove(StringHash eventType, VariantMap& eventData)
{
	if(gameState_ != GS_INGAME)
	{
		return;
	}
	
	int dx = eventData["DX"].GetInt();
	int dy = eventData["DY"].GetInt();
	
	float camYaw = cameraNode_.rotation.yaw + (dx * 0.25f);
	float camPitch = cameraNode_.rotation.pitch + (dy * 0.25f);
	camPitch = Clamp(camPitch, -20.0f, 70.0f);
	
	cameraNode_.rotation = Quaternion(camPitch, camYaw, 0.0f);
	radarScreenBase_.rotation = -cameraNode_.worldRotation.yaw;
}


void HandleMouseClick(StringHash eventType, VariantMap& eventData)
{
	if(gameState_ != GS_INGAME)
	{
		return;
	}
	
	int mouseButton = eventData["Button"].GetInt();
	
	if(mouseButton == MOUSEB_LEFT)
	{
		Fire();
	}
}


void HandleFixedUpdate(StringHash eventType, VariantMap& eventData)
{
	float timeStep = eventData["TimeStep"].GetFloat();
	float droneSpawnRate = 0.0;
		
	gamePhaseCounter_ += timeStep;
	if(gamePhaseCounter_ >= CRITICAL_PHASE)
	{
		droneSpawnRate = CRITICAL_PHASE_RATE;
		gamePhaseCounter_ = CRITICAL_PHASE;		
	}
	else if(gamePhaseCounter_ >= MODERATE_PHASE)
	{
		droneSpawnRate = MODERATE_PHASE_RATE;
	}
	else
	{
		droneSpawnRate = EASY_PHASE_RATE;
	}
	
	
	
	droneSpawnCounter_ +=timeStep;
	if(droneSpawnCounter_ >= droneSpawnRate)
	{
		if(scene_.GetChildrenWithScript("DroneObject",true).length < MAX_DRONE_COUNT)
		{
			SpawnDrone();
			UpdateDroneSprites();
			droneSpawnCounter_ = 0;
		}
	}
	
	
	spriteUpdateCounter_ += timeStep;
	
	if(spriteUpdateCounter_ >= SPRITE_UPDATE_TIME)
	{
		UpdateDroneSprites();
		spriteUpdateCounter_ = 0;
	}
	

}

void HandlePlayerHit(StringHash eventType, VariantMap& eventData)
{
	//Update Health
	float playerHealthFraction = eventData["CurrentHealthFraction"].GetFloat();
	
	
	int range = 512 - ( 512 * playerHealthFraction);
	healthFillSprite_.imageRect = IntRect(range, 0, 512 + range, 64);
	UpdateHealthTexture(playerHealthFraction);
	
	
	//Show Warning
	radarScreenBase_.SetAttributeAnimation("Color", valAnim_, WM_ONCE);
	PlaySoundFX(cameraNode_,"Resources/Sounds/boom5.ogg");
	
	if(playerHealthFraction == 0)
	{
		playerDestroyed_ = true;
	}
}

void HandleDroneHit(StringHash eventType, VariantMap& eventData)
{
	playerScore_ += SCORE_ADDITION_RATE;
	UpdateScoreDisplay();
}

void HandleDroneDestroyed(StringHash eventType, VariantMap& eventData)
{
	Vector3 dronePosition = eventData["DronePosition"].GetVector3();
	SpawnExplosion(dronePosition);
}

void HandleCountFinished(StringHash eventType, VariantMap& eventData)
{
	scene_.updateEnabled = true;
	gameState_ = GS_INGAME;
	
	targetSprite_.visible = true;
	enemyCounterText_.text = 0;
	playerScoreText_.text = 0;
}

void UpdateScoreDisplay()
{
	playerScoreText_.text = playerScore_;
}
 

void SpawnExplosion(Vector3 position)
{
	Node@ explosionNode = scene_.CreateChild("ExplosionNode");
	explosionNode.worldPosition = position;
	
	ParticleEmitter@ pEmitter = explosionNode.CreateComponent("ParticleEmitter");
	pEmitter.effect = cache.GetResource("ParticleEffect", "Resources/Particles/explosion.xml");
	pEmitter.enabled = true;
	 
	explosionNode.CreateScriptObject(scriptFile, "ExplosionObject");
	PlaySoundFX(explosionNode, "Resources/Sounds/explosion.ogg");
}


void SpawnDrone()
{
	Node@ droneNode = scene_.CreateChild();
	droneNode.SetScale(3.0f);
	AnimatedModel@ droneBody = droneNode.CreateComponent("AnimatedModel");
	droneBody.model = cache.GetResource("Model", "Resources/Models/drone_body.mdl");
	droneBody.material = cache.GetResource("Material", "Resources/Materials/drone_body.xml");
	
	AnimatedModel@ droneArm = droneNode.CreateComponent("AnimatedModel");
	droneArm.model = cache.GetResource("Model", "Resources/Models/drone_arm.mdl");
	droneArm.material = cache.GetResource("Material", "Resources/Materials/drone_arm.xml");
	
	RigidBody@ droneRB = droneNode.CreateComponent("RigidBody");
	droneRB.mass = 1.0f;
	droneRB.SetCollisionLayerAndMask(DRONE_COLLISION_LAYER, BULLET_COLLISION_LAYER | PLAYER_COLLISION_LAYER | FLOOR_COLLISION_LAYER);
	droneRB.kinematic = true;
	
	CollisionShape@ droneCS = droneNode.CreateComponent("CollisionShape");
	droneCS.SetSphere(0.3f);
	
	droneNode.CreateScriptObject(scriptFile,"DroneObject");
	AnimationController@ animController = droneNode.CreateComponent("AnimationController");
	animController.PlayExclusive("Resources/Models/open_arm.ani", 0, false);
	
	float nodeYaw = Random(360);
	droneNode.rotation = Quaternion(0,nodeYaw, 0);
	droneNode.Translate(Vector3(0,7,40));
	droneNode.vars["Sprite"] = CreateDroneSprite();
	
}


Sprite@ CreateDroneSprite()
{
	Texture2D@ droneSpriteTex = cache.GetResource("Texture2D", "Resources/Textures/drone_sprite.png");
	Sprite@ droneSprite = radarScreenBase_.CreateChild("Sprite");
	
	droneSprite.texture = droneSpriteTex;
	droneSprite.SetSize(6,6);
	droneSprite.SetAlignment(HA_CENTER, VA_CENTER);
	droneSprite.SetHotSpot(3,3);
	droneSprite.blendMode = BLEND_ALPHA;
	droneSprite.priority = 1;
	
	return droneSprite;
}


void UpdateDroneSprites()
{
	Array<Node@> droneNodes = scene_.GetChildrenWithScript("DroneObject",true);
	
	for(uint i=0; i < droneNodes.length ; i++)
	{
		Node@ droneNode = droneNodes[i];
		Sprite@ nodeSprite = droneNode.vars["Sprite"].GetPtr();
		nodeSprite.position = Vector2(droneNode.worldPosition.x, -(droneNode.worldPosition.z))* SCENE_TO_UI_SCALE;
		
	}
	
	enemyCounterText_.text = droneNodes.length;
}

void UpdateHealthTexture(float healthFraction)
{
	if(healthFraction > 0.5)
	{
		healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_green.png");
	}
	else if(healthFraction > 0.2)
	{
		healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_yellow.png");
	}
	else
	{
		healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_red.png");
	}
}

void Fire()
{	
	SpawnBullet(true);
	SpawnBullet(false);
	PlaySoundFX(cameraNode_,"Resources/Sounds/boom1.wav");
}

void SpawnBullet(bool first)
{
	Node@ pNode = scene_.CreateChild();
	pNode.worldPosition = cameraNode_.worldPosition;
	pNode.rotation = cameraNode_.worldRotation;
	
	float xOffSet = 0.3f * (first ? 1 : -1);
	pNode.Translate(Vector3(xOffSet,-0.2,0));
	
	BillboardSet@ bbSet = pNode.CreateComponent("BillboardSet");
	bbSet.numBillboards = 1;
	bbSet.material = cache.GetResource("Material", "Resources/Materials/bullet_particle.xml");
	
	ParticleEmitter@ pEmitter = pNode.CreateComponent("ParticleEmitter");
	pEmitter.effect = cache.GetResource("ParticleEffect", "Resources/Particles/bullet_particle.xml");
	pEmitter.enabled = true;
	
	pNode.CreateScriptObject(scriptFile, "BulletObject");
	
	
	
	RigidBody@ objBody = pNode.CreateComponent("RigidBody");
	objBody.mass = 1.0f;
	objBody.trigger = true;
	objBody.useGravity = false;
	objBody.ccdRadius = 0.05;
	objBody.ccdMotionThreshold = 0.15f;
	objBody.SetCollisionLayerAndMask(BULLET_COLLISION_LAYER, DRONE_COLLISION_LAYER | FLOOR_COLLISION_LAYER);
	
	CollisionShape@ objShape = pNode.CreateComponent("CollisionShape");
	objShape.SetSphere(0.3f);
	objBody.linearVelocity = pNode.rotation * Vector3(0,0,70);
}


void PlaySoundFX(Node@ soundNode, String soundName)
{
	SoundSource3D@ source = soundNode.CreateComponent("SoundSource3D");
	
	Sound@ sound = cache.GetResource("Sound", soundName);
    source.SetDistanceAttenuation(0.2, 120, 0.1);
	source.soundType = SOUND_EFFECT;
    source.Play(sound);
    source.autoRemove = true;
}
