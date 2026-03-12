import inspect
from enum import IntEnum
from typing import Any, Dict, List, Optional, Type

from pydantic import BaseModel, ConfigDict, Field


class TestCasePriority(IntEnum):
    HIGH = 6
    MEDIUM = 7
    LOW = 8
    NO_PRIORITY = 4

class TestCaseType(IntEnum):
    NON_FUNCTIONAL = 1
    FUNCTIONAL = 2

class PytestInfo(BaseModel):
    """Structured pytest information with validation."""
    name: str = Field(..., min_length=1, description="Test case name")
    nodeid: str = Field(..., description="Pytest node ID")
    module: str = Field(..., description="Python module name")
    class_name: Optional[str] = Field(None, description="Test class name if any")
    file_path: str = Field(..., description="File path of the test")
    docstring: Optional[str] = Field(None, description="Test function docstring")
    markers: List[str] = Field(default_factory=list, description="Pytest markers")

    model_config = ConfigDict(
        validate_assignment=True,
        extra="forbid"
    )

class TestCase(BaseModel):
    """Massive test case representation with all TestRail functionality built-in."""

    pytest_info: PytestInfo
    manifest_data: Dict[str, Any] = Field(default_factory=dict, description="Test manifest data")
    run_info: Dict[str, Any] = Field(default_factory=dict, description="Test run execution info")
    
    # TestRail specific fields
    testrail_case_id: Optional[int] = Field(None, description="TestRail case ID")
    testrail_case_data: Dict[str, Any] = Field(default_factory=dict, description="Full TestRail case data")
    testrail_test_id: Optional[int] = Field(None, description="TestRail test ID in current run")

    model_config = ConfigDict(
        validate_assignment=True,
        arbitrary_types_allowed=True
    )

    @classmethod
    def from_pytest_item(cls: Type["TestCase"], pytest_item: Any, manifest_data: Optional[Dict[str, Any]] = None) -> \
            "TestCase":
        """Factory method to create from a pytest item."""
        pytest_info = PytestInfo(
            name=pytest_item.name,
            nodeid=pytest_item.nodeid,
            module=pytest_item.module.__name__ if hasattr(pytest_item, 'module') else 'unknown',
            class_name=pytest_item.cls.__name__ if hasattr(pytest_item, 'cls') and pytest_item.cls else None,
            file_path=str(pytest_item.fspath) if hasattr(pytest_item, 'fspath') else 'unknown',
            docstring=inspect.getdoc(pytest_item.function) if hasattr(pytest_item, 'function') else None,
            markers=[marker.name for marker in pytest_item.iter_markers()]
        )

        test_case = cls(pytest_info=pytest_info, manifest_data=manifest_data or {})

        # Store the actual function for source code extraction
        test_case._pytest_function = getattr(pytest_item, 'function', None)

        return test_case

    @property
    def name(self) -> str:
        """Test case name."""
        return self.pytest_info.name

    # ========== TestRail Properties ==========
    
    @property
    def exists_in_testrail(self) -> bool:
        """Check if a test case exists in TestRail."""
        return self.testrail_case_id is not None

    @property
    def needs_creation(self) -> bool:
        """Check if a test case needs to be created in TestRail."""
        return not self.exists_in_testrail

    @property
    def needs_update(self) -> bool:
        """Check if a test case needs to be updated in TestRail."""
        return self.exists_in_testrail

    @property
    def testrail_title(self) -> str:
        """TestRail case title."""
        return self.name

    @property
    def testrail_revision(self) -> Optional[str]:
        """TestRail revision field with test commit hash."""
        tests = self.manifest_data.get('tests', {})
        tests_source = tests.get('source', {})
        commit = tests_source.get('commit')
        return commit if commit else None

    @property
    def testrail_description(self) -> str:
        """TestRail case description with stable manifest data (no system version info)."""
        desc = self.pytest_info.docstring or f"Automated test: {self.name}"
        desc += f"\n\nModule: {self.pytest_info.module}"
        desc += f"\nTest located in: {self.pytest_info.file_path}"

        if self.pytest_info.class_name:
            desc += f"\nTest class: {self.pytest_info.class_name}"

        if self.pytest_info.markers:
            desc += f"\nTest markers: {', '.join(self.pytest_info.markers)}"

        # Add stable test manifest information (exclude system manifest details)
        if self.manifest_data:
            desc += "\n\n--- Test Manifest Information ---"

            # Test environment info
            test_env = self.manifest_data.get('test_environment', {})
            if test_env:
                desc += f"\nTest Environment Path: {test_env.get('registry_path', 'N/A')}"
                desc += f"\nTest Environment Version: {test_env.get('version', 'N/A')}"

            # Tests source info (but not commit hash - that goes in revision field)
            tests = self.manifest_data.get('tests', {})
            tests_source = tests.get('source', {})
            if tests_source:
                desc += f"\nTest Repository: {tests_source.get('repository', 'N/A')}"
                desc += f"\nTest Branch: {tests_source.get('branch', 'N/A')}"

            # Metadata
            metadata = self.manifest_data.get('metadata', {})
            if metadata.get('description'):
                desc += f"\nManifest Description: {metadata['description']}"

        return desc

    @property
    def testrail_steps(self) -> List[Dict[str, str]]:
        """TestRail test steps as separated steps."""
        steps = [
            {
                "content": f"Execute automated test: {self.name}"
                           f"\nTest Code in the step below",
                "expected": "Test execution begins"
            },
            {
                "content": self._get_test_source_code(),
                "expected": "Test executes successfully"
            },
            {
                "content": "Verify test completion",
                "expected": "Test passes without errors"
            }
        ]
        return steps

    def _get_test_source_code(self) -> str:
        """Extract the source code of the test function."""
        try:
            # Get the test function from the pytest item
            test_func = getattr(self, '_pytest_function', None)
            if test_func is None:
                return "   # Source code not available"

            # Get the source code
            source_lines = inspect.getsourcelines(test_func)[0]

            # Format with proper indentation
            formatted_lines = []
            for line in source_lines:
                formatted_lines.append(f"   {line.rstrip()}")

            return '\n'.join(formatted_lines)

        except (OSError, TypeError) as e:
            return f"   # Could not retrieve source code: {e}"

    @property
    def testrail_priority_id(self) -> TestCasePriority:
        """Determine priority based on markers."""
        if 'high' in self.pytest_info.markers:
            return TestCasePriority.HIGH
        elif 'medium' in self.pytest_info.markers:
            return TestCasePriority.MEDIUM
        elif 'low' in self.pytest_info.markers:
            return TestCasePriority.LOW
        else:
            return TestCasePriority.NO_PRIORITY

    @property
    def testrail_type_id(self) -> TestCaseType:
        """Return type ID for automated tests.
        1 - Non-functional
        2 - Functional
        """
        return TestCaseType.FUNCTIONAL

    @property
    def testrail_fields(self) -> Dict[str, Any]:
        """Get all TestRail fields for creation/update."""
        fields = {
            'title': self.testrail_title,
            'custom_descr': self.testrail_description,
            'custom_steps_separated': self.testrail_steps,
            'priority_id': self.testrail_priority_id.value,
            'type_id': self.testrail_type_id.value,
        }
        
        # Add revision if available
        if self.testrail_revision:
            fields['custom_tcrevision'] = self.testrail_revision
            
        return fields

    @property
    def testrail_fields_for_update(self) -> Dict[str, Any]:
        """Get TestRail fields for updates (includes revision tracking)."""
        fields = self.testrail_fields.copy()
        
        # Always update revision on case updates to track test changes
        if self.testrail_revision:
            fields['custom_tcrevision'] = self.testrail_revision
            
        return fields

    # ========== TestRail Methods ==========
    
    def set_testrail_data(self, testrail_case_dict: Dict[str, Any]) -> None:
        """Set TestRail data for this test case."""
        self.testrail_case_id = testrail_case_dict.get('id')
        self.testrail_case_data = testrail_case_dict

    def set_testrail_test_id(self, test_id: int) -> None:
        """Set the TestRail test ID for the current run."""
        self.testrail_test_id = test_id

    def has_testrail_test_id(self) -> bool:
        """Check if test case has a run test ID."""
        return self.testrail_test_id is not None

    def needs_revision_update(self) -> bool:
        """Check if the test case revision needs updating."""
        if not self.testrail_revision:
            return False
        
        current_revision = self.testrail_case_data.get('custom_tcrevision')
        return current_revision != self.testrail_revision

    # ========== Utility Methods ==========
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return self.model_dump()

    def to_json(self) -> str:
        """Convert to JSON string."""
        return self.model_dump_json()

    def needs_update_from_manifest(self) -> bool:
        """Check if test case needs updating based on manifest data changes."""
        if not self.exists_in_testrail:
            return False
        
        # Always check if manifest data has changed
        current_data = self.testrail_case_data
        
        # Check revision (test commit hash)
        if self.testrail_revision and current_data.get('custom_tcrevision') != self.testrail_revision:
            return True
        
        # Check description content (manifest data changes)
        if current_data.get('custom_descr') != self.testrail_description:
            return True
        
        return False

    def needs_update_from_pytest_changes(self) -> bool:
        """Check if test case needs updating based on pytest info changes."""
        if not self.exists_in_testrail:
            return False
        
        current_data = self.testrail_case_data
        
        # Check if test steps changed (source code, docstring, etc.)
        current_steps = current_data.get('custom_steps_separated', [])
        new_steps = self.testrail_steps
        
        # Simple comparison - if lengths differ or content differs
        if len(current_steps) != len(new_steps):
            return True
        
        for current_step, new_step in zip(current_steps, new_steps):
            if (current_step.get('content') != new_step.get('content') or 
                current_step.get('expected') != new_step.get('expected')):
                return True
        
        # Check if priority changed (based on markers)
        if current_data.get('priority_id') != self.testrail_priority_id.value:
            return True
        
        return False

    def get_update_fields_manifest_only(self) -> Dict[str, Any]:
        """Get fields that should be updated from manifest changes only."""
        fields = {}
        
        # Always update manifest-derived fields
        fields['custom_descr'] = self.testrail_description
        
        if self.testrail_revision:
            fields['custom_tcrevision'] = self.testrail_revision
        
        return fields

    def get_update_fields_pytest_changes(self) -> Dict[str, Any]:
        """Get fields that should be updated from pytest info changes."""
        fields = {}
        
        # Update pytest-derived fields
        fields['custom_steps_separated'] = self.testrail_steps
        fields['priority_id'] = self.testrail_priority_id.value
        
        return fields

    def get_update_fields_comprehensive(self) -> Dict[str, Any]:
        """Get all fields for a comprehensive update (manifest + pytest changes)."""
        fields = self.get_update_fields_manifest_only()
        fields.update(self.get_update_fields_pytest_changes())
        return fields
